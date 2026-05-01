/**
 * Unit tests for BridgeHost — validates plugin connection handling,
 * handshake acceptance, session tracking, health endpoint integration,
 * and disconnect events.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import http from 'http';
import { BridgeHost, type PluginSessionInfo } from './bridge-host.js';

function connectPlugin(port: number): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/plugin`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function httpGet(
  port: number,
  path: string
): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    http
      .get(`http://localhost:${port}${path}`, (res) => {
        let body = '';
        res.on('data', (chunk: Buffer | string) => {
          body += chunk;
        });
        res.on('end', () => {
          resolve({ status: res.statusCode ?? 0, body });
        });
        res.on('error', reject);
      })
      .on('error', reject);
  });
}

async function performRegisterHandshake(
  port: number,
  sessionId: string,
  options?: {
    capabilities?: string[];
    pluginVersion?: string;
    instanceId?: string;
    placeName?: string;
    state?: string;
  }
): Promise<{ ws: WebSocket }> {
  const ws = await connectPlugin(port);

  ws.send(
    JSON.stringify({
      type: 'register',
      sessionId,
      payload: {
        pluginVersion: options?.pluginVersion ?? '1.0.0',
        instanceId: options?.instanceId ?? 'inst-1',
        placeName: options?.placeName ?? 'TestPlace',
        state: options?.state ?? 'Edit',
        capabilities: options?.capabilities ?? ['execute', 'queryState'],
      },
    })
  );

  // Allow the host to process the register message
  await new Promise((r) => setTimeout(r, 10));
  return { ws };
}

describe('BridgeHost', () => {
  let host: BridgeHost | undefined;
  const openClients: WebSocket[] = [];

  afterEach(async () => {
    for (const ws of openClients) {
      if (
        ws.readyState === WebSocket.OPEN ||
        ws.readyState === WebSocket.CONNECTING
      ) {
        ws.close();
      }
    }
    openClients.length = 0;

    if (host) {
      await host.stopAsync();
      host = undefined;
    }
  });

  describe('startAsync', () => {
    it('starts on an ephemeral port and reports port', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      expect(port).toBeGreaterThan(0);
      expect(host.port).toBe(port);
      expect(host.isRunning).toBe(true);
    });

    it('throws when started twice', async () => {
      host = new BridgeHost();
      await host.startAsync({ port: 0 });

      await expect(host.startAsync({ port: 0 })).rejects.toThrow(
        'BridgeHost is already running'
      );
    });
  });

  describe('stopAsync', () => {
    it('stops the host and resets state', async () => {
      host = new BridgeHost();
      await host.startAsync({ port: 0 });

      await host.stopAsync();

      expect(host.isRunning).toBe(false);
      expect(host.pluginCount).toBe(0);
    });

    it('is idempotent', async () => {
      host = new BridgeHost();
      await host.startAsync({ port: 0 });

      await host.stopAsync();
      await host.stopAsync();
    });
  });

  describe('register handshake', () => {
    it('emits plugin-connected with session info on register', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const connectedPromise = new Promise<PluginSessionInfo>((resolve) => {
        host!.on('plugin-connected', resolve);
      });

      const { ws } = await performRegisterHandshake(port, 'session-1', {
        capabilities: ['execute', 'captureScreenshot'],
        pluginVersion: '2.0.0',
      });
      openClients.push(ws);

      const info = await connectedPromise;
      expect(info.sessionId).toBe('session-1');
      expect(info.capabilities).toEqual(['execute', 'captureScreenshot']);
      expect(info.pluginVersion).toBe('2.0.0');
    });

    it('tracks the plugin in pluginCount', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      expect(host.pluginCount).toBe(0);

      const { ws } = await performRegisterHandshake(port, 'session-1');
      openClients.push(ws);

      expect(host.pluginCount).toBe(1);
    });
  });

  describe('plugin disconnect', () => {
    it('emits plugin-disconnected when a plugin closes', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const { ws } = await performRegisterHandshake(port, 'session-dc');
      openClients.push(ws);

      // Wait for the plugin to be registered
      await new Promise((r) => setTimeout(r, 50));
      expect(host.pluginCount).toBe(1);

      const disconnectedPromise = new Promise<string>((resolve) => {
        host!.on('plugin-disconnected', resolve);
      });

      ws.close();
      const sessionId = await disconnectedPromise;

      expect(sessionId).toBe('session-dc');
      expect(host.pluginCount).toBe(0);
    });

    it('tracks multiple plugins and removes only the disconnected one', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const { ws: ws1 } = await performRegisterHandshake(port, 'session-1');
      openClients.push(ws1);
      const { ws: ws2 } = await performRegisterHandshake(port, 'session-2');
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 50));
      expect(host.pluginCount).toBe(2);

      const disconnectedPromise = new Promise<string>((resolve) => {
        host!.on('plugin-disconnected', resolve);
      });

      ws1.close();
      await disconnectedPromise;

      expect(host.pluginCount).toBe(1);
    });

    it('handles duplicate sessionId by replacing old connection', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      // Connect first plugin
      const { ws: ws1 } = await performRegisterHandshake(port, 'session-dup');
      openClients.push(ws1);
      await new Promise((r) => setTimeout(r, 50));
      expect(host.pluginCount).toBe(1);

      // Connect second plugin with the SAME sessionId
      const { ws: ws2 } = await performRegisterHandshake(port, 'session-dup');
      openClients.push(ws2);
      await new Promise((r) => setTimeout(r, 50));

      // Should still be 1 — second replaced first
      expect(host.pluginCount).toBe(1);

      // Old socket should have been closed by the host
      await new Promise((r) => setTimeout(r, 100));
      expect(ws1.readyState).toBe(WebSocket.CLOSED);
      expect(ws2.readyState).toBe(WebSocket.OPEN);
    });

    it('old close handler does not remove new connection with same sessionId', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      // Connect two plugins with the same sessionId
      const { ws: ws1 } = await performRegisterHandshake(port, 'session-race');
      openClients.push(ws1);
      await new Promise((r) => setTimeout(r, 50));

      const { ws: ws2 } = await performRegisterHandshake(port, 'session-race');
      openClients.push(ws2);

      // Wait for close frames to propagate
      await new Promise((r) => setTimeout(r, 200));

      // ws2 should still be tracked despite ws1's close handler firing
      expect(host.pluginCount).toBe(1);
      expect(ws2.readyState).toBe(WebSocket.OPEN);
    });
  });

  describe('health endpoint', () => {
    it('responds with valid JSON on /health', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const result = await httpGet(port, '/health');

      expect(result.status).toBe(200);
      const json = JSON.parse(result.body);
      expect(json.status).toBe('ok');
      expect(json.port).toBe(port);
      expect(json.sessions).toBe(0);
      expect(typeof json.uptime).toBe('number');
    });

    it('reflects correct session count', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      // Connect a plugin
      const { ws } = await performRegisterHandshake(port, 'session-h');
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      const result = await httpGet(port, '/health');
      const json = JSON.parse(result.body);
      expect(json.sessions).toBe(1);
    });

    it('returns 404 for unknown HTTP paths', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const result = await httpGet(port, '/unknown');
      expect(result.status).toBe(404);
    });
  });

  describe('sendToPluginAsync request correlation', () => {
    /**
     * The persistent dispatcher routes plugin replies by `requestId` via a
     * per-connection PendingRequestMap. This was previously a per-call
     * `ws.on('message', ...)` listener that matched the first non-heartbeat
     * reply, which could (a) leak listeners under load and (b) cross
     * responses when ≥2 requests were in flight.
     */

    function readNextMessageAsync(ws: WebSocket): Promise<any> {
      return new Promise((resolve, reject) => {
        const onMessage = (raw: Buffer | ArrayBuffer | Buffer[]) => {
          ws.off('message', onMessage);
          ws.off('error', onError);
          const data =
            typeof raw === 'string'
              ? raw
              : Buffer.isBuffer(raw)
              ? raw.toString('utf-8')
              : Buffer.concat(raw as Buffer[]).toString('utf-8');
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(e);
          }
        };
        const onError = (err: Error) => {
          ws.off('message', onMessage);
          ws.off('error', onError);
          reject(err);
        };
        ws.on('message', onMessage);
        ws.on('error', onError);
      });
    }

    it('routes concurrent in-flight responses to the correct callers', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });
      const sessionId = 'concurrent-test';
      const { ws } = await performRegisterHandshake(port, sessionId);
      openClients.push(ws);

      // Fire two requests in parallel — they should resolve independently
      // by requestId, even if the plugin replies in reverse order.
      const firstRequestPromise = readNextMessageAsync(ws);
      const reply1 = host.sendToPluginAsync<{ requestId: string; tag: string }>(
        sessionId,
        {
          type: 'execute',
          sessionId,
          requestId: 'req-1',
          payload: { script: 'print(1)' },
        },
        2_000
      );
      const sent1 = await firstRequestPromise;
      expect(sent1.requestId).toBe('req-1');

      const secondRequestPromise = readNextMessageAsync(ws);
      const reply2 = host.sendToPluginAsync<{ requestId: string; tag: string }>(
        sessionId,
        {
          type: 'execute',
          sessionId,
          requestId: 'req-2',
          payload: { script: 'print(2)' },
        },
        2_000
      );
      const sent2 = await secondRequestPromise;
      expect(sent2.requestId).toBe('req-2');

      // Reply to req-2 first, then req-1.
      ws.send(
        JSON.stringify({
          type: 'scriptComplete',
          sessionId,
          requestId: 'req-2',
          tag: 'second',
          payload: { success: true },
        })
      );
      ws.send(
        JSON.stringify({
          type: 'scriptComplete',
          sessionId,
          requestId: 'req-1',
          tag: 'first',
          payload: { success: true },
        })
      );

      const [r1, r2] = await Promise.all([reply1, reply2]);
      expect(r1.requestId).toBe('req-1');
      expect(r1.tag).toBe('first');
      expect(r2.requestId).toBe('req-2');
      expect(r2.tag).toBe('second');
    });

    it('does not satisfy a request with an unrelated error reply', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });
      const sessionId = 'unrelated-error';
      const { ws } = await performRegisterHandshake(port, sessionId);
      openClients.push(ws);

      const drained = readNextMessageAsync(ws);
      const replyPromise = host.sendToPluginAsync(
        sessionId,
        {
          type: 'execute',
          sessionId,
          requestId: 'req-real',
          payload: { script: 'print()' },
        },
        300
      );
      await drained;

      // Send an error reply with a *different* requestId. It must NOT
      // satisfy req-real; req-real should still time out.
      ws.send(
        JSON.stringify({
          type: 'error',
          sessionId,
          requestId: 'some-other-request',
          payload: { code: 'INTERNAL_ERROR', message: 'unrelated' },
        })
      );

      await expect(replyPromise).rejects.toThrow(/timed out/);
    });

    it('rejects pending requests when the plugin disconnects', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });
      const sessionId = 'disconnect-test';
      const { ws } = await performRegisterHandshake(port, sessionId);
      openClients.push(ws);

      const drained = readNextMessageAsync(ws);
      const replyPromise = host.sendToPluginAsync(
        sessionId,
        {
          type: 'execute',
          sessionId,
          requestId: 'req-x',
          payload: { script: 'print()' },
        },
        10_000
      );
      await drained;

      ws.close();
      await expect(replyPromise).rejects.toThrow(/disconnect/i);
    });

    it('does not leak ws listeners across many requests', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });
      const sessionId = 'no-leak';
      const { ws: clientWs } = await performRegisterHandshake(port, sessionId);
      openClients.push(clientWs);

      // Reach into the host to grab the *server-side* WebSocket — that's the
      // one the dispatcher attaches to.
      const state = (host as any)._plugins.get(sessionId) as
        | { ws: WebSocket }
        | undefined;
      expect(state).toBeDefined();
      const baselineListeners = state!.ws.listenerCount('message');

      // Fire 25 requests, replying immediately to each.
      const requests: Promise<unknown>[] = [];
      for (let i = 0; i < 25; i++) {
        const requestId = `bulk-${i}`;
        const drained = readNextMessageAsync(clientWs);
        requests.push(
          host.sendToPluginAsync(
            sessionId,
            {
              type: 'execute',
              sessionId,
              requestId,
              payload: { script: 'print()' },
            },
            5_000
          )
        );
        await drained;
        clientWs.send(
          JSON.stringify({
            type: 'scriptComplete',
            sessionId,
            requestId,
            payload: { success: true },
          })
        );
      }
      await Promise.all(requests);

      // Listener count is unchanged — the dispatcher is installed once.
      expect(state!.ws.listenerCount('message')).toBe(baselineListeners);
    });
  });
});
