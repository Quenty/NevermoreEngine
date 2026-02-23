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
// Tests: 1.3d1 -- connectAsync() and Role Detection
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
  // connectAsync and role detection
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

      // Wait for event processing
      await new Promise((r) => setTimeout(r, 50));

      expect(conn.listSessions()).toHaveLength(1);
    });
  });

  // -----------------------------------------------------------------------
  // disconnectAsync
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

      // Connect a plugin
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
});
