/**
 * Unit tests for BridgeConnection -- validates role detection, connection
 * lifecycle, session listing, resolution, waiting, and event forwarding.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import { BridgeConnection } from './bridge-connection.js';

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

async function performRegisterHandshake(
  port: number,
  sessionId: string,
  options?: {
    instanceId?: string;
    placeName?: string;
    state?: string;
    context?: string;
    capabilities?: string[];
  },
): Promise<{ ws: WebSocket; welcome: Record<string, unknown> }> {
  const ws = await connectPlugin(port);
  const welcomePromise = waitForMessage(ws);

  ws.send(JSON.stringify({
    type: 'register',
    sessionId,
    protocolVersion: 2,
    payload: {
      pluginVersion: '1.0.0',
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

describe('BridgeConnection', () => {
  const openClients: WebSocket[] = [];
  const connections: BridgeConnection[] = [];

  afterEach(async () => {
    for (const ws of openClients) {
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        ws.close();
      }
    }
    openClients.length = 0;

    for (const conn of [...connections].reverse()) {
      await conn.disconnectAsync();
    }
    connections.length = 0;
  });

  // -----------------------------------------------------------------------
  // connectAsync and role detection (1.3d1)
  // -----------------------------------------------------------------------

  describe('connectAsync', () => {
    it('becomes host on unused ephemeral port', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      expect(conn.role).toBe('host');
      expect(conn.isConnected).toBe(true);
      expect(conn.port).toBeGreaterThan(0);
    });

    it('accepts plugin connections as host', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-1');
      openClients.push(ws);

      await new Promise((r) => setTimeout(r, 50));

      expect(conn.listSessions()).toHaveLength(1);
    });
  });

  // -----------------------------------------------------------------------
  // disconnectAsync (1.3d1)
  // -----------------------------------------------------------------------

  describe('disconnectAsync', () => {
    it('sets isConnected to false', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      expect(conn.isConnected).toBe(true);

      await conn.disconnectAsync();
      connections.length = 0;

      expect(conn.isConnected).toBe(false);
    });

    it('is idempotent', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });

      await conn.disconnectAsync();
      await conn.disconnectAsync();

      expect(conn.isConnected).toBe(false);
    });

    it('cleans up host resources', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-1');
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      expect(conn.listSessions()).toHaveLength(1);

      await conn.disconnectAsync();
      connections.length = 0;

      expect(conn.isConnected).toBe(false);
      expect(conn.listSessions()).toEqual([]);
    });
  });

  // -----------------------------------------------------------------------
  // listSessions (1.3d2)
  // -----------------------------------------------------------------------

  describe('listSessions', () => {
    it('returns empty list when no plugins connected', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      expect(conn.listSessions()).toEqual([]);
    });

    it('returns sessions from connected plugins', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'session-a', {
        instanceId: 'inst-A',
        placeName: 'PlaceA',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'session-b', {
        instanceId: 'inst-B',
        placeName: 'PlaceB',
      });
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 50));

      const sessions = conn.listSessions();
      expect(sessions).toHaveLength(2);
      expect(sessions.map((s) => s.sessionId).sort()).toEqual(['session-a', 'session-b']);
    });

    it('removes session when plugin disconnects', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-dc');
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      expect(conn.listSessions()).toHaveLength(1);

      ws.close();
      await new Promise((r) => setTimeout(r, 100));

      expect(conn.listSessions()).toHaveLength(0);
    });
  });

  // -----------------------------------------------------------------------
  // listInstances (1.3d2)
  // -----------------------------------------------------------------------

  describe('listInstances', () => {
    it('returns empty list when no plugins connected', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      expect(conn.listInstances()).toEqual([]);
    });

    it('groups sessions by instanceId', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      // Two sessions from the same instance (edit + server contexts)
      // Context is derived from state: 'Edit' -> 'edit', 'Server' -> 'server'
      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'session-edit', {
        instanceId: 'inst-A',
        placeName: 'PlaceA',
        state: 'Edit',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'session-server', {
        instanceId: 'inst-A',
        placeName: 'PlaceA',
        state: 'Server',
      });
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 50));

      const instances = conn.listInstances();
      expect(instances).toHaveLength(1);
      expect(instances[0].instanceId).toBe('inst-A');
      expect(instances[0].contexts.sort()).toEqual(['edit', 'server']);
    });

    it('separates different instances', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'session-1', {
        instanceId: 'inst-A',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'session-2', {
        instanceId: 'inst-B',
      });
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 50));

      const instances = conn.listInstances();
      expect(instances).toHaveLength(2);
      expect(instances.map((i) => i.instanceId).sort()).toEqual(['inst-A', 'inst-B']);
    });
  });

  // -----------------------------------------------------------------------
  // getSession (1.3d2)
  // -----------------------------------------------------------------------

  describe('getSession', () => {
    it('returns a BridgeSession for a known session', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-x', {
        instanceId: 'inst-1',
        placeName: 'TestPlace',
      });
      openClients.push(ws);

      await new Promise((r) => setTimeout(r, 50));

      const session = conn.getSession('session-x');
      expect(session).toBeDefined();
      expect(session!.info.sessionId).toBe('session-x');
    });

    it('returns undefined for unknown session', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      expect(conn.getSession('nonexistent')).toBeUndefined();
    });

    it('returns undefined after plugin disconnects', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-gone');
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      expect(conn.getSession('session-gone')).toBeDefined();

      ws.close();
      await new Promise((r) => setTimeout(r, 100));

      expect(conn.getSession('session-gone')).toBeUndefined();
    });
  });
});
