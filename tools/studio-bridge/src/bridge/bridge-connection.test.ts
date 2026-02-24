/**
 * Unit tests for BridgeConnection -- validates role detection, connection
 * lifecycle, session listing, resolution, waiting, and event forwarding.
 */

import { describe, it, expect, afterEach, vi } from 'vitest';
import { WebSocket } from 'ws';
import { BridgeConnection } from './bridge-connection.js';
import { SessionNotFoundError, ContextNotFoundError } from './types.js';
import type { BridgeSession } from './bridge-session.js';

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

  // -----------------------------------------------------------------------
  // resolveSession (1.3d3)
  // -----------------------------------------------------------------------

  describe('resolveSession', () => {
    it('throws "No sessions connected" when no sessions exist', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      // resolveSession waits up to 5s for a plugin to connect when acting as
      // host with no sessions, so we need a longer test timeout
      await expect(conn.resolveSession()).rejects.toThrow(SessionNotFoundError);
      await expect(conn.resolveSession()).rejects.toThrow('No sessions connected');
    }, 15_000);

    it('returns the only session automatically', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'only-session', {
        instanceId: 'inst-1',
      });
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      const session = await conn.resolveSession();
      expect(session.info.sessionId).toBe('only-session');
    });

    it('throws with instance list when multiple instances exist', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'session-1', {
        instanceId: 'inst-A',
        placeName: 'PlaceA',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'session-2', {
        instanceId: 'inst-B',
        placeName: 'PlaceB',
      });
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 50));

      await expect(conn.resolveSession()).rejects.toThrow(SessionNotFoundError);
      await expect(conn.resolveSession()).rejects.toThrow('Multiple Studio instances');
    });

    it('returns specific session by sessionId', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-abc', {
        instanceId: 'inst-1',
      });
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      const session = await conn.resolveSession('session-abc');
      expect(session.info.sessionId).toBe('session-abc');
    });

    it('throws SessionNotFoundError for unknown sessionId', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      await expect(conn.resolveSession('nonexistent')).rejects.toThrow(SessionNotFoundError);
      await expect(conn.resolveSession('nonexistent')).rejects.toThrow("Session 'nonexistent' not found");
    });

    it('returns Edit context by default when multiple contexts exist', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      // Simulate Play mode: edit + server + client contexts
      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'edit-session', {
        instanceId: 'inst-1',
        state: 'Edit',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'server-session', {
        instanceId: 'inst-1',
        state: 'Server',
      });
      openClients.push(ws2);

      const { ws: ws3 } = await performRegisterHandshake(conn.port, 'client-session', {
        instanceId: 'inst-1',
        state: 'Client',
      });
      openClients.push(ws3);

      await new Promise((r) => setTimeout(r, 50));

      // Should return the Edit context by default
      const session = await conn.resolveSession();
      expect(session.info.sessionId).toBe('edit-session');
      expect(session.context).toBe('edit');
    });

    it('returns specific context when requested', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'edit-s', {
        instanceId: 'inst-1',
        state: 'Edit',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'server-s', {
        instanceId: 'inst-1',
        state: 'Server',
      });
      openClients.push(ws2);

      const { ws: ws3 } = await performRegisterHandshake(conn.port, 'client-s', {
        instanceId: 'inst-1',
        state: 'Client',
      });
      openClients.push(ws3);

      await new Promise((r) => setTimeout(r, 50));

      const serverSession = await conn.resolveSession(undefined, 'server');
      expect(serverSession.info.sessionId).toBe('server-s');
      expect(serverSession.context).toBe('server');

      const clientSession = await conn.resolveSession(undefined, 'client');
      expect(clientSession.info.sessionId).toBe('client-s');
      expect(clientSession.context).toBe('client');
    });

    it('throws ContextNotFoundError for unavailable context', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      // Only edit context connected
      const { ws } = await performRegisterHandshake(conn.port, 'edit-only', {
        instanceId: 'inst-1',
        state: 'Edit',
      });
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      await expect(conn.resolveSession(undefined, 'server')).rejects.toThrow(ContextNotFoundError);
    });

    it('resolves by instanceId', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'session-A', {
        instanceId: 'inst-A',
        placeName: 'PlaceA',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'session-B', {
        instanceId: 'inst-B',
        placeName: 'PlaceB',
      });
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 50));

      const session = await conn.resolveSession(undefined, undefined, 'inst-B');
      expect(session.info.sessionId).toBe('session-B');
    });

    it('resolves by instanceId and context', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'edit-s', {
        instanceId: 'inst-1',
        state: 'Edit',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'server-s', {
        instanceId: 'inst-1',
        state: 'Server',
      });
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 50));

      const session = await conn.resolveSession(undefined, 'server', 'inst-1');
      expect(session.info.sessionId).toBe('server-s');
    });

    it('throws SessionNotFoundError for unknown instanceId', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-1', {
        instanceId: 'inst-1',
      });
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      await expect(
        conn.resolveSession(undefined, undefined, 'nonexistent-inst'),
      ).rejects.toThrow(SessionNotFoundError);
    });
  });

  // -----------------------------------------------------------------------
  // waitForSession (1.3d4)
  // -----------------------------------------------------------------------

  describe('waitForSession', () => {
    it('resolves immediately when sessions already exist', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'existing-session', {
        instanceId: 'inst-1',
      });
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      const session = await conn.waitForSession();
      expect(session.info.sessionId).toBe('existing-session');
    });

    it('resolves when a plugin connects', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      // Start waiting before plugin connects
      const waitPromise = conn.waitForSession(5000);

      // Connect plugin after a short delay
      setTimeout(async () => {
        const { ws } = await performRegisterHandshake(conn.port, 'late-session', {
          instanceId: 'inst-1',
        });
        openClients.push(ws);
      }, 100);

      const session = await waitPromise;
      expect(session.info.sessionId).toBe('late-session');
    });

    it('rejects after timeout with no plugin', async () => {
      vi.useFakeTimers();

      try {
        const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
        connections.push(conn);

        const waitPromise = conn.waitForSession(500);

        // Advance past the timeout
        vi.advanceTimersByTime(600);

        await expect(waitPromise).rejects.toThrow('Timed out waiting for a session');
      } finally {
        vi.useRealTimers();
      }
    });
  });

  // -----------------------------------------------------------------------
  // Lifecycle events (1.3d4)
  // -----------------------------------------------------------------------

  describe('events', () => {
    it('emits session-connected when plugin registers', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const connectedPromise = new Promise<BridgeSession>((resolve) => {
        conn.on('session-connected', resolve);
      });

      const { ws } = await performRegisterHandshake(conn.port, 'session-evt', {
        instanceId: 'inst-1',
      });
      openClients.push(ws);

      const session = await connectedPromise;
      expect(session.info.sessionId).toBe('session-evt');
    });

    it('emits session-disconnected when plugin closes', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-dc', {
        instanceId: 'inst-1',
      });
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      const disconnectedPromise = new Promise<string>((resolve) => {
        conn.on('session-disconnected', resolve);
      });

      ws.close();

      const sessionId = await disconnectedPromise;
      expect(sessionId).toBe('session-dc');
    });

    it('emits instance-connected for first session of an instance', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const instancePromise = new Promise<{ instanceId: string }>((resolve) => {
        conn.on('instance-connected', (instance) => {
          resolve(instance);
        });
      });

      const { ws } = await performRegisterHandshake(conn.port, 'session-1', {
        instanceId: 'inst-new',
        placeName: 'NewPlace',
      });
      openClients.push(ws);

      const instance = await instancePromise;
      expect(instance.instanceId).toBe('inst-new');
    });

    it('emits instance-disconnected when last session of an instance disconnects', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const { ws } = await performRegisterHandshake(conn.port, 'session-last', {
        instanceId: 'inst-only',
      });
      openClients.push(ws);
      await new Promise((r) => setTimeout(r, 50));

      const instanceDisconnectedPromise = new Promise<string>((resolve) => {
        conn.on('instance-disconnected', resolve);
      });

      ws.close();

      const instanceId = await instanceDisconnectedPromise;
      expect(instanceId).toBe('inst-only');
    });

    it('does not emit instance-disconnected when other contexts remain', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      // Connect edit and server contexts for the same instance
      const { ws: wsEdit } = await performRegisterHandshake(conn.port, 'edit-ctx', {
        instanceId: 'inst-play',
        state: 'Edit',
      });
      openClients.push(wsEdit);

      const { ws: wsServer } = await performRegisterHandshake(conn.port, 'server-ctx', {
        instanceId: 'inst-play',
        state: 'Server',
      });
      openClients.push(wsServer);

      await new Promise((r) => setTimeout(r, 50));

      let instanceDisconnectedFired = false;
      conn.on('instance-disconnected', () => {
        instanceDisconnectedFired = true;
      });

      // Disconnect only the server context
      const sessionDisconnectedPromise = new Promise<string>((resolve) => {
        conn.on('session-disconnected', resolve);
      });

      wsServer.close();
      await sessionDisconnectedPromise;

      // Wait a bit more to ensure no stray event
      await new Promise((r) => setTimeout(r, 50));

      // instance-disconnected should NOT have fired (edit context still connected)
      expect(instanceDisconnectedFired).toBe(false);
      expect(conn.listInstances()).toHaveLength(1);
    });

    it('fires multiple session-connected events for multiple plugins', async () => {
      const conn = await BridgeConnection.connectAsync({ port: 0, keepAlive: true });
      connections.push(conn);

      const connectedIds: string[] = [];
      conn.on('session-connected', (session: BridgeSession) => {
        connectedIds.push(session.info.sessionId);
      });

      const { ws: ws1 } = await performRegisterHandshake(conn.port, 'session-1', {
        instanceId: 'inst-1',
      });
      openClients.push(ws1);

      const { ws: ws2 } = await performRegisterHandshake(conn.port, 'session-2', {
        instanceId: 'inst-2',
      });
      openClients.push(ws2);

      await new Promise((r) => setTimeout(r, 100));

      expect(connectedIds.sort()).toEqual(['session-1', 'session-2']);
    });
  });
});
