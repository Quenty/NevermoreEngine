/**
 * End-to-end tests for split-server mode. A BridgeHost accepts plugin
 * connections on /plugin and CLI client connections on /client. Verifies
 * that multiple clients can coexist with the host without interfering
 * with plugin sessions.
 *
 * Note: The current BridgeHost does not implement full host-protocol
 * message routing (list-sessions, host-envelope relay). These tests
 * exercise the real transport layer and connection lifecycle, not the
 * relay protocol. Split-server relay is tested via BridgeConnection
 * with a mock host (see bridge-connection-remote.test.ts).
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import { BridgeHost } from '../../bridge/internal/bridge-host.js';
import { MockPluginClient } from '../helpers/mock-plugin-client.js';
import type { PluginSessionInfo } from '../../bridge/internal/bridge-host.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function connectClient(port: number): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/client`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('split-server e2e', () => {
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
      await host.stopAsync();
      host = undefined;
    }
  });

  // -----------------------------------------------------------------------
  // Client connects to existing host
  // -----------------------------------------------------------------------

  it('client connects to existing host', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });
    expect(port).toBeGreaterThan(0);

    // Connect a plugin
    const plugin = new MockPluginClient({
      port,
      instanceId: 'inst-split-1',
      placeName: 'SplitPlace',
    });
    plugins.push(plugin);
    await plugin.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    expect(host.pluginCount).toBe(1);

    // Connect a client on /client path
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    expect(clientWs.readyState).toBe(WebSocket.OPEN);
  });

  // -----------------------------------------------------------------------
  // Client can list sessions from host (via events)
  // -----------------------------------------------------------------------

  it('client can list sessions from host via plugin-connected events', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Track plugin-connected events
    const connectedSessions: PluginSessionInfo[] = [];
    host.on('plugin-connected', (info: PluginSessionInfo) => {
      connectedSessions.push(info);
    });

    // Connect two plugins
    const pluginA = new MockPluginClient({
      port,
      instanceId: 'inst-list-A',
      placeName: 'PlaceA',
    });
    plugins.push(pluginA);
    await pluginA.connectAndRegisterAsync();

    const pluginB = new MockPluginClient({
      port,
      instanceId: 'inst-list-B',
      placeName: 'PlaceB',
    });
    plugins.push(pluginB);
    await pluginB.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    expect(host.pluginCount).toBe(2);
    expect(connectedSessions).toHaveLength(2);

    const sessionIds = connectedSessions.map((s) => s.sessionId).sort();
    expect(sessionIds).toContain(pluginA.sessionId);
    expect(sessionIds).toContain(pluginB.sessionId);

    // Verify instance metadata
    const sessionA = connectedSessions.find((s) => s.sessionId === pluginA.sessionId);
    expect(sessionA!.placeName).toBe('PlaceA');
    expect(sessionA!.instanceId).toBe('inst-list-A');

    const sessionB = connectedSessions.find((s) => s.sessionId === pluginB.sessionId);
    expect(sessionB!.placeName).toBe('PlaceB');
    expect(sessionB!.instanceId).toBe('inst-list-B');
  });

  // -----------------------------------------------------------------------
  // Commands relayed through host (plugin receives execute)
  // -----------------------------------------------------------------------

  it('plugin and client coexist on the same host without interference', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect plugin with execute capability
    const plugin = new MockPluginClient({
      port,
      instanceId: 'inst-relay',
      capabilities: ['execute', 'queryState'],
    });
    plugins.push(plugin);
    await plugin.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    // Connect a client
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    // Both connections should be active
    expect(host.pluginCount).toBe(1);
    expect(plugin.isConnected).toBe(true);
    expect(clientWs.readyState).toBe(WebSocket.OPEN);

    // Plugin can send heartbeats without affecting the client
    plugin.sendMessage({
      type: 'heartbeat',
      sessionId: plugin.sessionId,
      payload: {
        uptimeMs: 5000,
        state: 'Edit',
        pendingRequests: 0,
      },
    });

    await new Promise((r) => setTimeout(r, 50));

    // Client can send data without affecting the plugin
    clientWs.send(JSON.stringify({ type: 'ping' }));

    await new Promise((r) => setTimeout(r, 50));

    // Both should still be connected
    expect(plugin.isConnected).toBe(true);
    expect(clientWs.readyState).toBe(WebSocket.OPEN);
    expect(host.pluginCount).toBe(1);
  });

  // -----------------------------------------------------------------------
  // Client disconnect does not affect host or plugin
  // -----------------------------------------------------------------------

  it('client disconnect does not affect host or plugin', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    const plugin = new MockPluginClient({
      port,
      instanceId: 'inst-client-dc',
    });
    plugins.push(plugin);
    await plugin.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    // Connect client
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    expect(host.pluginCount).toBe(1);

    // Disconnect the client
    clientWs.close();
    await new Promise((r) => setTimeout(r, 100));

    // Host should still be running
    expect(host.isRunning).toBe(true);
    expect(host.pluginCount).toBe(1);

    // Plugin should still be connected
    expect(plugin.isConnected).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Plugin disconnect is tracked independently from client
  // -----------------------------------------------------------------------

  it('plugin disconnect does not affect connected clients', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    const plugin = new MockPluginClient({
      port,
      instanceId: 'inst-plugin-dc',
    });
    plugins.push(plugin);
    await plugin.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    // Connect a client
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    // Track plugin disconnect
    const disconnectedPromise = new Promise<string>((resolve) => {
      host!.on('plugin-disconnected', resolve);
    });

    // Disconnect the plugin
    await plugin.disconnectAsync();

    const disconnectedId = await disconnectedPromise;
    expect(disconnectedId).toBe(plugin.sessionId);

    // Host still running
    expect(host.isRunning).toBe(true);
    expect(host.pluginCount).toBe(0);

    // Client still connected
    expect(clientWs.readyState).toBe(WebSocket.OPEN);
  });

  // -----------------------------------------------------------------------
  // Health endpoint works alongside WebSocket connections
  // -----------------------------------------------------------------------

  it('health endpoint returns correct data with active connections', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect a plugin
    const plugin = new MockPluginClient({
      port,
      instanceId: 'inst-health',
    });
    plugins.push(plugin);
    await plugin.connectAndRegisterAsync();
    await new Promise((r) => setTimeout(r, 50));

    // Check health endpoint
    const res = await fetch(`http://localhost:${port}/health`);
    expect(res.status).toBe(200);

    const body = await res.json() as Record<string, unknown>;
    expect(body.status).toBe('ok');
    expect(body.port).toBe(port);
    expect(body.protocolVersion).toBe(2);
    expect(body.sessions).toBe(1);
  });

  // -----------------------------------------------------------------------
  // Graceful shutdown broadcasts transfer notice to clients
  // -----------------------------------------------------------------------

  it('graceful shutdown sends host-transfer notice to clients', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect a client
    const clientWs = await connectClient(port);
    clients.push(clientWs);

    // Listen for host-transfer message
    const transferPromise = new Promise<Record<string, unknown>>((resolve) => {
      clientWs.on('message', (raw) => {
        const data = JSON.parse(
          typeof raw === 'string' ? raw : raw.toString('utf-8'),
        );
        if (data.type === 'host-transfer') {
          resolve(data);
        }
      });
    });

    // Graceful shutdown
    await host.shutdownAsync();

    // The client should have received the host-transfer notice
    const transferMsg = await transferPromise;
    expect(transferMsg.type).toBe('host-transfer');
  });
});
