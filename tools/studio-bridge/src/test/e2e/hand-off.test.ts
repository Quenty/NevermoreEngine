/**
 * End-to-end tests for failover scenarios. Exercises the hand-off state
 * machine with real WebSocket connections and TCP port binding.
 *
 * Tests cover: graceful host shutdown with HostTransferNotice, and
 * client promotion after port becomes available.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import { BridgeHost } from '../../bridge/internal/bridge-host.js';
import { HandOffManager } from '../../bridge/internal/hand-off.js';
import { MockPluginClient } from '../helpers/mock-plugin-client.js';
import { createServer, type Server } from 'net';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Connect as a client to the host's /client WebSocket path.
 */
function connectClient(port: number): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/client`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

/**
 * Wait for a specific message type on a WebSocket.
 */
function waitForWsMessage(
  ws: WebSocket,
  type: string,
  timeoutMs = 5_000,
): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Timed out waiting for '${type}' message after ${timeoutMs}ms`));
    }, timeoutMs);

    ws.on('message', (raw) => {
      const data = JSON.parse(
        typeof raw === 'string' ? raw : raw.toString('utf-8'),
      );
      if (data.type === type) {
        clearTimeout(timer);
        resolve(data);
      }
    });
  });
}

/**
 * Try to bind a TCP server to a port. Returns true if successful.
 */
function tryBindPortAsync(port: number): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    const server: Server = createServer();
    server.once('error', () => resolve(false));
    server.once('listening', () => {
      server.close(() => resolve(true));
    });
    server.listen(port, 'localhost');
  });
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('hand-off e2e', () => {
  let host: BridgeHost | undefined;
  const plugins: MockPluginClient[] = [];
  const clients: WebSocket[] = [];

  afterEach(async () => {
    for (const plugin of plugins) {
      await plugin.disconnectAsync();
    }
    plugins.length = 0;

    for (const ws of clients) {
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        ws.close();
      }
    }
    clients.length = 0;

    if (host) {
      await host.stopAsync().catch(() => {});
      host = undefined;
    }
  });

  // -----------------------------------------------------------------------
  // Graceful shutdown with HostTransferNotice
  // -----------------------------------------------------------------------

  it('client receives host-transfer notice on graceful shutdown', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect a client
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    // Listen for host-transfer message
    const transferPromise = waitForWsMessage(clientWs, 'host-transfer');

    // Graceful shutdown
    await host.shutdownAsync();
    host = undefined; // Already shut down

    const transferMsg = await transferPromise;
    expect(transferMsg.type).toBe('host-transfer');
  });

  // -----------------------------------------------------------------------
  // Client promotes to host when host shuts down gracefully
  // -----------------------------------------------------------------------

  it('client promotes to host when host shuts down gracefully', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect a plugin
    const plugin = new MockPluginClient({
      port,
      instanceId: 'inst-failover',
      placeName: 'FailoverPlace',
    });
    plugins.push(plugin);
    await plugin.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    expect(host.pluginCount).toBe(1);

    // Connect a client (simulating another bridge process)
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    // Wait for transfer notice
    const transferPromise = waitForWsMessage(clientWs, 'host-transfer');

    // Gracefully shut down the host
    await host.shutdownAsync();
    host = undefined; // Already shut down

    await transferPromise;

    // Wait for port to be released
    await new Promise((r) => setTimeout(r, 200));

    // The port should now be free for the client to take over.
    // Use the HandOffManager to simulate the takeover with real port binding.
    const handOff = new HandOffManager({ port });
    handOff.onHostTransferNotice();
    const result = await handOff.onHostDisconnectedAsync();

    expect(result).toBe('promoted');
    expect(handOff.state).toBe('promoted');

    // Verify the port is now bindable (we released it in onHostDisconnectedAsync
    // via tryBindAsync which binds and immediately releases)
    const canBind = await tryBindPortAsync(port);
    expect(canBind).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Commands work through promoted host
  // -----------------------------------------------------------------------

  it('commands work through promoted host', async () => {
    // Start a host on ephemeral port
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect a client
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    // Gracefully shut down
    const transferPromise = waitForWsMessage(clientWs, 'host-transfer');
    await host.shutdownAsync();
    host = undefined;
    await transferPromise;

    await new Promise((r) => setTimeout(r, 200));

    // Promote: start a new host on the same port
    const newHost = new BridgeHost();
    newHost.markFailover();
    const newPort = await newHost.startAsync({ port });
    host = newHost;

    expect(newPort).toBe(port);
    expect(newHost.isRunning).toBe(true);

    // Connect a new plugin to the promoted host
    const plugin = new MockPluginClient({
      port: newPort,
      instanceId: 'inst-promoted',
      placeName: 'PromotedPlace',
    });
    plugins.push(plugin);
    await plugin.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    expect(newHost.pluginCount).toBe(1);

    // The health endpoint should work
    const res = await fetch(`http://localhost:${newPort}/health`);
    expect(res.status).toBe(200);
    const body = await res.json() as Record<string, unknown>;
    expect(body.status).toBe('ok');
    expect(body.sessions).toBe(1);
    expect(body.lastFailoverAt).not.toBeNull();
  });

  // -----------------------------------------------------------------------
  // HandOffManager state machine with real port binding
  // -----------------------------------------------------------------------

  it('HandOffManager promotes when port is free', async () => {
    // Bind a port, then release it, and have HandOff detect the free port
    const tempServer = createServer();
    const port = await new Promise<number>((resolve) => {
      tempServer.listen(0, 'localhost', () => {
        const addr = tempServer.address();
        if (typeof addr === 'object' && addr !== null) {
          resolve(addr.port);
        }
      });
    });

    // Release the port
    await new Promise<void>((resolve) => tempServer.close(() => resolve()));

    // HandOff should be able to bind
    const handOff = new HandOffManager({ port });
    handOff.onHostTransferNotice();
    const result = await handOff.onHostDisconnectedAsync();

    expect(result).toBe('promoted');
    expect(handOff.state).toBe('promoted');
  });

  it('HandOffManager falls back to client when another host takes over', async () => {
    // Start a host to hold the port
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // HandOff should see the port is in use and try to connect as client
    // We use custom deps to simulate the client connection succeeding
    const handOff = new HandOffManager({
      port,
      deps: {
        tryBindAsync: async (p: number) => {
          // Will fail because host holds the port
          return new Promise<boolean>((resolve) => {
            const server: Server = createServer();
            server.once('error', () => resolve(false));
            server.once('listening', () => {
              server.close(() => resolve(true));
            });
            server.listen(p, 'localhost');
          });
        },
        tryConnectAsClientAsync: async (p: number) => {
          // Try connecting to /client
          return new Promise<boolean>((resolve) => {
            const ws = new WebSocket(`ws://localhost:${p}/client`);
            const timer = setTimeout(() => {
              ws.removeAllListeners();
              ws.terminate();
              resolve(false);
            }, 2_000);
            ws.once('open', () => {
              clearTimeout(timer);
              ws.close();
              resolve(true);
            });
            ws.once('error', () => {
              clearTimeout(timer);
              resolve(false);
            });
          });
        },
        delay: (ms: number) => new Promise((resolve) => setTimeout(resolve, ms)),
      },
    });

    handOff.onHostTransferNotice();
    const result = await handOff.onHostDisconnectedAsync();

    expect(result).toBe('fell-back-to-client');
    expect(handOff.state).toBe('fell-back-to-client');
  });

  // -----------------------------------------------------------------------
  // Multiple plugins survive host restart
  // -----------------------------------------------------------------------

  it('new host accepts plugins after failover', async () => {
    // Start original host
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect a plugin
    const plugin1 = new MockPluginClient({
      port,
      instanceId: 'inst-original',
      placeName: 'OriginalPlace',
    });
    plugins.push(plugin1);
    await plugin1.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));
    expect(host.pluginCount).toBe(1);

    // Shut down the host
    await host.shutdownAsync();
    host = undefined;

    await new Promise((r) => setTimeout(r, 200));

    // The original plugin is now disconnected
    expect(plugin1.isConnected).toBe(false);

    // Start a new host on the same port (simulating promotion)
    const newHost = new BridgeHost();
    newHost.markFailover();
    const newPort = await newHost.startAsync({ port });
    host = newHost;

    expect(newPort).toBe(port);

    // A new plugin connects to the promoted host
    const plugin2 = new MockPluginClient({
      port: newPort,
      instanceId: 'inst-new',
      placeName: 'NewPlace',
    });
    plugins.push(plugin2);
    await plugin2.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    expect(newHost.pluginCount).toBe(1);

    // Verify the health endpoint reflects the failover
    const res = await fetch(`http://localhost:${newPort}/health`);
    const body = await res.json() as Record<string, unknown>;
    expect(body.sessions).toBe(1);
    expect(body.lastFailoverAt).not.toBeNull();
  });
});
