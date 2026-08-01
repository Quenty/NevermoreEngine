import { describe, it, expect, afterEach } from 'vitest';
import { createServer, type Server } from 'http';
import { WebSocketServer, type WebSocket } from 'ws';
import {
  type WatchStreamNotify,
  type WatchStreamReady,
} from '@quenty/nevermore-deploy';
import { WebSocketWatchStream } from './websocket-watch-stream.js';

const REGISTER_BASE = 'https://watch.example.com/v1/register/30m/';

function makeReady(
  overrides: Partial<WatchStreamReady> = {}
): WatchStreamReady {
  return {
    type: 'ready',
    monitorId: 'mon_1',
    repository: 'Quenty/egg-hunt-2026',
    name: 'egg-hunt/integration/local',
    leaseExpiresAt: '2026-08-01T00:00:00Z',
    serverTime: '2026-07-31T00:00:00Z',
    watches: [],
    ...overrides,
  };
}

interface Harness {
  url: string;
  /** Every connection the server accepted, with the path and headers it was given. */
  connections: {
    url?: string;
    headers: Record<string, string | string[] | undefined>;
  }[];
  onConnect: (socket: WebSocket, index: number) => void;
  closeAsync: () => Promise<void>;
}

const harnesses: Harness[] = [];
const plainServers: Server[] = [];

afterEach(async () => {
  while (harnesses.length > 0) {
    await harnesses.pop()!.closeAsync();
  }
  while (plainServers.length > 0) {
    const server = plainServers.pop()!;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

async function startServerAsync(
  onConnect: (socket: WebSocket, index: number) => void
): Promise<Harness> {
  const wss = new WebSocketServer({ port: 0 });
  await new Promise<void>((resolve) => wss.once('listening', resolve));
  const { port } = wss.address() as { port: number };

  const harness: Harness = {
    url: `http://127.0.0.1:${port}/v1/register/30m/`,
    connections: [],
    onConnect,
    closeAsync: () =>
      new Promise<void>((resolve) => {
        for (const client of wss.clients) {
          client.terminate();
        }
        wss.close(() => resolve());
      }),
  };

  wss.on('connection', (socket, request) => {
    const index = harness.connections.length;
    harness.connections.push({ url: request.url, headers: request.headers });
    harness.onConnect(socket, index);
  });

  harnesses.push(harness);
  return harness;
}

/** An HTTP server that answers the handshake without upgrading, like a proxy that ate it. */
async function startPlainServerAsync(
  status: number,
  body: unknown
): Promise<{ url: string; requests: number }> {
  const state = { url: '', requests: 0 };
  const server = createServer((_req, res) => {
    state.requests++;
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as { port: number };
  state.url = `http://127.0.0.1:${port}/v1/register/30m/`;
  plainServers.push(server);
  return state;
}

function noopHandlers() {
  return {
    onReadyAsync: async () => {},
    onNotifyAsync: async () => {},
  };
}

describe('WebSocketWatchStream URL derivation', () => {
  // The register endpoint is the only place a service address is configured —
  // this repo is public and must never carry one — so the stream URL has to be
  // derived from it rather than configured a second time.
  it('derives the stream path from the register endpoint', async () => {
    const seen: string[] = [];
    const stream = new WebSocketWatchStream({
      registerUrl: REGISTER_BASE,
      connect: (url) => {
        seen.push(url);
        throw new Error('stop connecting');
      },
    });

    await expect(
      stream.runAsync({
        monitorId: 'mon_abc',
        credential: 'token',
        signal: new AbortController().signal,
        handlers: noopHandlers(),
      })
    ).rejects.toThrowError(/stop connecting/);

    expect(seen).toEqual([
      'wss://watch.example.com/v1/monitors/mon_abc/stream',
    ]);
  });

  it('speaks ws over a plaintext endpoint', async () => {
    const seen: string[] = [];
    const stream = new WebSocketWatchStream({
      registerUrl: 'http://localhost:3002/v1/register/30m/',
      connect: (url) => {
        seen.push(url);
        throw new Error('stop connecting');
      },
    });

    await expect(
      stream.runAsync({
        monitorId: 'mon_abc',
        credential: 'token',
        signal: new AbortController().signal,
        handlers: noopHandlers(),
      })
    ).rejects.toThrowError(/stop connecting/);

    expect(seen).toEqual(['ws://localhost:3002/v1/monitors/mon_abc/stream']);
  });

  it('rejects an endpoint that is not a register URL', async () => {
    const stream = new WebSocketWatchStream({
      registerUrl: 'https://watch.example.com/elsewhere/30m/',
      connect: () => {
        throw new Error('should not connect');
      },
    });

    await expect(
      stream.runAsync({
        monitorId: 'mon_abc',
        credential: 'token',
        signal: new AbortController().signal,
        handlers: noopHandlers(),
      })
    ).rejects.toThrowError(/expected its path to contain/);
  });
});

describe('WebSocketWatchStream', () => {
  it('connects with a bearer header and no token in the URL', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket) => {
      socket.send(JSON.stringify(makeReady()));
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    const ready: WatchStreamReady[] = [];

    const run = stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'ghp_secret',
      signal: controller.signal,
      handlers: {
        onReadyAsync: async (message) => {
          ready.push(message);
          controller.abort();
        },
        onNotifyAsync: async () => {},
      },
    });

    const result = await run;

    expect(ready).toHaveLength(1);
    expect(result.ending).toBe('aborted');
    expect(harness.connections[0]!.headers['authorization']).toBe(
      'Bearer ghp_secret'
    );
    // Never as a query parameter: a PAT in a URL lands in every access log
    // between here and the service.
    expect(harness.connections[0]!.url).toBe('/v1/monitors/mon_abc/stream');
  });

  it('delivers notifications and counts them', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket) => {
      socket.send(JSON.stringify(makeReady()));
      socket.send(
        JSON.stringify({
          type: 'notify',
          watchName: 'hub',
          sourceId: 'src_1',
          version: '159',
          previousVersion: '158',
          payload: { target: 'integration.places.hub' },
          at: '2026-07-31T00:00:00Z',
        })
      );
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    const notifications: WatchStreamNotify[] = [];

    const result = await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: {
        onReadyAsync: async () => {},
        onNotifyAsync: async (message) => {
          notifications.push(message);
          controller.abort();
        },
      },
    });

    expect(notifications[0]!.version).toBe('159');
    expect(notifications[0]!.payload).toEqual({
      target: 'integration.places.hub',
    });
    expect(result.notifications).toBe(1);
  });

  // Reconnection lives inside the stream precisely so a caller cannot skip the
  // reconcile: every connection, including a retry, opens with `ready`.
  it('reconnects after a drop and re-delivers ready', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket, index) => {
      socket.send(JSON.stringify(makeReady()));
      if (index === 0) {
        socket.close();
      }
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    let readyCount = 0;

    const result = await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: {
        onReadyAsync: async () => {
          readyCount++;
          if (readyCount === 2) {
            controller.abort();
          }
        },
        onNotifyAsync: async () => {},
      },
    });

    expect(readyCount).toBe(2);
    expect(result.reconnects).toBe(1);
  });

  // A lease that lapsed is a finished watch, not a fault: retrying the socket
  // would fail forever against a monitor that no longer exists.
  it('stops rather than retrying when the monitor is gone', async () => {
    const harness = await startServerAsync((socket) => {
      socket.close(4004, 'monitor released');
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    const result = await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: new AbortController().signal,
      handlers: noopHandlers(),
    });

    expect(result.ending).toBe('monitor-gone');
    expect(harness.connections).toHaveLength(1);
  });

  // A websocket that fails to upgrade reports only "Unexpected server response:
  // <status>" — the same sentence for a stripped Upgrade header and a dead
  // token. Observed live: nginx in front of the service was not forwarding the
  // upgrade, and the client retried forever saying nothing useful.
  it('explains a 426 as a proxy stripping the upgrade, and keeps retrying', async () => {
    const controller = new AbortController();
    const server = await startPlainServerAsync(426, {
      error: 'This endpoint is a websocket.',
    });

    const stream = new WebSocketWatchStream({ registerUrl: server.url });
    const reasons: string[] = [];

    const result = await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: {
        ...noopHandlers(),
        onReconnect: (_attempt, reason) => {
          reasons.push(reason);
          controller.abort();
        },
      },
    });

    expect(reasons[0]).toMatch(/Upgrade header/);
    expect(reasons[0]).toMatch(
      /proxy configuration problem on the service side/
    );
    // Not permanent: a proxy fix should be picked up without restarting.
    expect(result.ending).toBe('aborted');
  });

  it.each([
    [401, /NEVERMORE_WATCH_TOKEN/],
    [404, /cannot write to the/],
  ])(
    'stops on a %i rather than retrying a dead token',
    async (status, match) => {
      const server = await startPlainServerAsync(status, { error: 'nope' });

      const stream = new WebSocketWatchStream({ registerUrl: server.url });
      const result = await stream.runAsync({
        monitorId: 'mon_abc',
        credential: 'token',
        signal: new AbortController().signal,
        handlers: noopHandlers(),
      });

      expect(result.ending).toBe('rejected');
      expect(result.reason).toMatch(match);
      expect(server.requests).toBe(1);
    }
  );

  // Reproduced before the fix: a throwing handler left runAsync unresolved and
  // raised an unhandled rejection, which under Node's default kills the CLI.
  // The watch has to outlive a bad handler, not hang on one.
  it('survives a handler that throws, and keeps delivering', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket) => {
      socket.send(JSON.stringify(makeReady()));
      for (const version of ['159', '160']) {
        socket.send(
          JSON.stringify({
            type: 'notify',
            watchName: 'hub',
            sourceId: 'src_1',
            version,
            previousVersion: null,
            payload: {},
            at: '2026-07-31T00:00:00Z',
          })
        );
      }
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    const seen: string[] = [];
    const errors: Error[] = [];

    const result = await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: {
        onReadyAsync: async () => {
          throw new Error('ready handler exploded');
        },
        onNotifyAsync: async (message) => {
          seen.push(message.version!);
          if (seen.length === 2) {
            controller.abort();
          }
        },
        onHandlerError: (err) => errors.push(err),
      },
    });

    // A rejected tail must not swallow every later frame.
    expect(seen).toEqual(['159', '160']);
    expect(errors.map((e) => e.message)).toEqual(['ready handler exploded']);
    expect(result.ending).toBe('aborted');
  });

  // Reproduced before the fix at ~94 connections a second: a server that sends
  // `ready` then closes 1001 was reconnected to with zero delay and no backoff,
  // aiming a stampede at something already failing.
  it('does not hot-loop against a server that greets then closes', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket) => {
      socket.send(JSON.stringify(makeReady()));
      socket.close(1001, 'Server shutting down');
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    setTimeout(() => controller.abort(), 1200);

    await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: noopHandlers(),
    });

    // Without the floor and the minimum-lifetime gate this ran into the
    // hundreds; a handful over a second is the whole point.
    expect(harness.connections.length).toBeLessThan(12);
    expect(harness.connections.length).toBeGreaterThan(1);
  });

  // The service retires a connection about hourly so reconnecting re-verifies
  // the token. Routine by design — warning about it every hour trains people to
  // ignore the warnings that matter.
  it('reconnects quietly after a 4005 retirement', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket, index) => {
      socket.send(JSON.stringify(makeReady()));
      if (index === 0) {
        socket.close(4005, 'Reconnect to re-authorize');
      }
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    const reported: string[] = [];
    let readyCount = 0;

    const result = await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: {
        onReadyAsync: async () => {
          readyCount++;
          if (readyCount === 2) {
            controller.abort();
          }
        },
        onNotifyAsync: async () => {},
        onReconnect: (_attempt, reason) => reported.push(reason),
      },
    });

    expect(readyCount).toBe(2);
    expect(reported).toEqual([]);
    expect(result.reconnects).toBe(1);
  });

  // A frame from a newer service is not a reason to drop a working connection.
  it('ignores a frame it cannot parse or does not know', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket) => {
      socket.send('not json at all');
      socket.send(JSON.stringify({ type: 'something-new', value: 1 }));
      socket.send(JSON.stringify(makeReady()));
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    let readyCount = 0;

    const result = await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: {
        onReadyAsync: async () => {
          readyCount++;
          controller.abort();
        },
        onNotifyAsync: async () => {},
      },
    });

    expect(readyCount).toBe(1);
    expect(result.ending).toBe('aborted');
  });

  // Messages arrive whenever they arrive; two rebuilds of the same place racing
  // each other's uploads is the failure this prevents.
  it('runs handlers one at a time', async () => {
    const controller = new AbortController();
    const harness = await startServerAsync((socket) => {
      socket.send(JSON.stringify(makeReady()));
      for (const version of ['159', '160']) {
        socket.send(
          JSON.stringify({
            type: 'notify',
            watchName: 'hub',
            sourceId: 'src_1',
            version,
            previousVersion: null,
            payload: {},
            at: '2026-07-31T00:00:00Z',
          })
        );
      }
    });

    const stream = new WebSocketWatchStream({ registerUrl: harness.url });
    const order: string[] = [];
    let inFlight = 0;
    let overlapped = false;

    await stream.runAsync({
      monitorId: 'mon_abc',
      credential: 'token',
      signal: controller.signal,
      handlers: {
        onReadyAsync: async () => {},
        onNotifyAsync: async (message) => {
          inFlight++;
          if (inFlight > 1) {
            overlapped = true;
          }
          await new Promise((resolve) => setTimeout(resolve, 20));
          order.push(message.version!);
          inFlight--;
          if (order.length === 2) {
            controller.abort();
          }
        },
      },
    });

    expect(overlapped).toBe(false);
    expect(order).toEqual(['159', '160']);
  });
});
