/**
 * Unit tests for BridgeHost — validates plugin connection handling,
 * handshake acceptance, session tracking, health endpoint integration,
 * and disconnect events.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import http from 'http';
import { BridgeHost, type PluginSessionInfo } from './bridge-host.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function connectPlugin(port: number): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/plugin`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function waitForMessage(ws: WebSocket): Promise<Record<string, unknown>> {
  return new Promise((resolve) => {
    ws.once('message', (raw) => {
      const data = JSON.parse(
        typeof raw === 'string' ? raw : raw.toString('utf-8'),
      );
      resolve(data);
    });
  });
}

function httpGet(port: number, path: string): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:${port}${path}`, (res) => {
      let body = '';
      res.on('data', (chunk: Buffer | string) => { body += chunk; });
      res.on('end', () => {
        resolve({ status: res.statusCode ?? 0, body });
      });
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function performHelloHandshake(
  port: number,
  sessionId: string,
  options?: { capabilities?: string[]; pluginVersion?: string },
): Promise<{ ws: WebSocket; welcome: Record<string, unknown> }> {
  const ws = await connectPlugin(port);

  const welcomePromise = waitForMessage(ws);

  ws.send(JSON.stringify({
    type: 'hello',
    sessionId,
    payload: {
      sessionId,
      pluginVersion: options?.pluginVersion,
      capabilities: options?.capabilities,
    },
  }));

  const welcome = await welcomePromise;
  return { ws, welcome };
}

async function performRegisterHandshake(
  port: number,
  sessionId: string,
  options?: {
    protocolVersion?: number;
    capabilities?: string[];
    pluginVersion?: string;
    instanceId?: string;
    placeName?: string;
    state?: string;
  },
): Promise<{ ws: WebSocket; welcome: Record<string, unknown> }> {
  const ws = await connectPlugin(port);

  const welcomePromise = waitForMessage(ws);

  ws.send(JSON.stringify({
    type: 'register',
    sessionId,
    protocolVersion: options?.protocolVersion ?? 2,
    payload: {
      pluginVersion: options?.pluginVersion ?? '1.0.0',
      instanceId: options?.instanceId ?? 'inst-1',
      placeName: options?.placeName ?? 'TestPlace',
      state: options?.state ?? 'Edit',
      capabilities: options?.capabilities ?? ['execute', 'queryState'],
    },
  }));

  const welcome = await welcomePromise;
  return { ws, welcome };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('BridgeHost', () => {
  let host: BridgeHost | undefined;
  const openClients: WebSocket[] = [];

  afterEach(async () => {
    for (const ws of openClients) {
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        ws.close();
      }
    }
    openClients.length = 0;

    if (host) {
      await host.stopAsync();
      host = undefined;
    }
  });

  // -----------------------------------------------------------------------
  // Startup and lifecycle
  // -----------------------------------------------------------------------

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
        'BridgeHost is already running',
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

  // -----------------------------------------------------------------------
  // Plugin handshake: hello (v1)
  // -----------------------------------------------------------------------

  describe('hello handshake', () => {
    it('accepts hello and sends welcome with correct sessionId', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const { ws, welcome } = await performHelloHandshake(port, 'session-1');
      openClients.push(ws);

      expect(welcome.type).toBe('welcome');
      expect((welcome.payload as Record<string, unknown>).sessionId).toBe('session-1');
    });

    it('emits plugin-connected event with session info', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const connectedPromise = new Promise<PluginSessionInfo>((resolve) => {
        host!.on('plugin-connected', resolve);
      });

      const { ws } = await performHelloHandshake(port, 'session-abc', {
        capabilities: ['execute', 'queryState'],
        pluginVersion: '1.2.0',
      });
      openClients.push(ws);

      const info = await connectedPromise;
      expect(info.sessionId).toBe('session-abc');
      expect(info.capabilities).toEqual(['execute', 'queryState']);
      expect(info.pluginVersion).toBe('1.2.0');
      expect(info.protocolVersion).toBe(1);
    });

    it('tracks the plugin in pluginCount', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      expect(host.pluginCount).toBe(0);

      const { ws } = await performHelloHandshake(port, 'session-1');
      openClients.push(ws);

      // Wait for event processing
      await new Promise((r) => setTimeout(r, 50));

      expect(host.pluginCount).toBe(1);
    });

    it('defaults capabilities to [execute] when not provided', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const connectedPromise = new Promise<PluginSessionInfo>((resolve) => {
        host!.on('plugin-connected', resolve);
      });

      const { ws } = await performHelloHandshake(port, 'session-1');
      openClients.push(ws);

      const info = await connectedPromise;
      expect(info.capabilities).toEqual(['execute']);
    });
  });

  // -----------------------------------------------------------------------
  // Plugin handshake: register (v2)
  // -----------------------------------------------------------------------

  describe('register handshake', () => {
    it('accepts register and sends v2 welcome with protocolVersion and capabilities', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const { ws, welcome } = await performRegisterHandshake(port, 'session-v2', {
        protocolVersion: 2,
        capabilities: ['execute', 'queryState'],
      });
      openClients.push(ws);

      expect(welcome.type).toBe('welcome');
      const payload = welcome.payload as Record<string, unknown>;
      expect(payload.sessionId).toBe('session-v2');
      expect(payload.protocolVersion).toBe(2);
      expect(payload.capabilities).toEqual(['execute', 'queryState']);
    });

    it('emits plugin-connected with v2 session info', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const connectedPromise = new Promise<PluginSessionInfo>((resolve) => {
        host!.on('plugin-connected', resolve);
      });

      const { ws } = await performRegisterHandshake(port, 'session-v2', {
        protocolVersion: 2,
        capabilities: ['execute', 'captureScreenshot'],
        pluginVersion: '2.0.0',
      });
      openClients.push(ws);

      const info = await connectedPromise;
      expect(info.sessionId).toBe('session-v2');
      expect(info.protocolVersion).toBe(2);
      expect(info.capabilities).toEqual(['execute', 'captureScreenshot']);
      expect(info.pluginVersion).toBe('2.0.0');
    });

    it('caps protocolVersion to server max (2)', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const { ws, welcome } = await performRegisterHandshake(port, 'session-v3', {
        protocolVersion: 5,
      });
      openClients.push(ws);

      const payload = welcome.payload as Record<string, unknown>;
      expect(payload.protocolVersion).toBe(2);
    });
  });

  // -----------------------------------------------------------------------
  // Plugin disconnect
  // -----------------------------------------------------------------------

  describe('plugin disconnect', () => {
    it('emits plugin-disconnected when a plugin closes', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const { ws } = await performHelloHandshake(port, 'session-dc');
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

      const { ws: ws1 } = await performHelloHandshake(port, 'session-1');
      openClients.push(ws1);
      const { ws: ws2 } = await performHelloHandshake(port, 'session-2');
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
  });

  // -----------------------------------------------------------------------
  // Health endpoint
  // -----------------------------------------------------------------------

  describe('health endpoint', () => {
    it('responds with valid JSON on /health', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      const result = await httpGet(port, '/health');

      expect(result.status).toBe(200);
      const json = JSON.parse(result.body);
      expect(json.status).toBe('ok');
      expect(json.port).toBe(port);
      expect(json.protocolVersion).toBe(2);
      expect(json.sessions).toBe(0);
      expect(typeof json.uptime).toBe('number');
    });

    it('reflects correct session count', async () => {
      host = new BridgeHost();
      const port = await host.startAsync({ port: 0 });

      // Connect a plugin
      const { ws } = await performHelloHandshake(port, 'session-h');
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
});
