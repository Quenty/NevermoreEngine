/**
 * Unit tests for remote connection support in BridgeConnection --
 * validates remoteHost parsing, default port behavior, ECONNREFUSED
 * error handling, and client-only connection mode.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocketServer } from 'ws';
import { BridgeConnection } from './bridge-connection.js';
import {
  encodeHostMessage,
  decodeHostMessage,
  type HostProtocolMessage,
} from './internal/host-protocol.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface MockHost {
  wss: WebSocketServer;
  port: number;
  receivedMessages: HostProtocolMessage[];
}

/**
 * Create a mock bridge host WebSocket server that serves on /client
 * and responds to list-sessions requests (matching the host protocol).
 */
async function createMockHostAsync(): Promise<MockHost> {
  const receivedMessages: HostProtocolMessage[] = [];

  const wss = new WebSocketServer({ port: 0, path: '/client' });

  const port = await new Promise<number>((resolve) => {
    wss.on('listening', () => {
      const addr = wss.address();
      if (typeof addr === 'object' && addr !== null) {
        resolve(addr.port);
      }
    });
  });

  wss.on('connection', (ws) => {
    ws.on('message', (raw) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = decodeHostMessage(data);
      if (msg) {
        receivedMessages.push(msg);

        // Auto-respond to list-sessions with empty list
        if (msg.type === 'list-sessions') {
          ws.send(encodeHostMessage({
            type: 'list-sessions-response',
            requestId: msg.requestId,
            sessions: [],
          }));
        }
      }
    });
  });

  return { wss, port, receivedMessages };
}

async function closeHostAsync(host: MockHost): Promise<void> {
  for (const client of host.wss.clients) {
    client.terminate();
  }
  await new Promise<void>((resolve) => {
    host.wss.close(() => resolve());
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('BridgeConnection remote mode', () => {
  let host: MockHost | undefined;
  const connections: BridgeConnection[] = [];

  afterEach(async () => {
    for (const conn of [...connections].reverse()) {
      await conn.disconnectAsync();
    }
    connections.length = 0;

    if (host) {
      await closeHostAsync(host);
      host = undefined;
    }
  });

  // -----------------------------------------------------------------------
  // remoteHost parsing
  // -----------------------------------------------------------------------

  describe('remoteHost parsing', () => {
    it('connects as client when remoteHost points to a running host', async () => {
      host = await createMockHostAsync();

      const conn = await BridgeConnection.connectAsync({
        remoteHost: `localhost:${host.port}`,
      });
      connections.push(conn);

      expect(conn.role).toBe('client');
      expect(conn.isConnected).toBe(true);
    });

    it('appends default port when no colon in remoteHost', async () => {
      // We can't easily test against default port 38741,
      // but we can verify parsing by using port option to override
      host = await createMockHostAsync();

      // When remoteHost has no colon, port comes from options.port
      const conn = await BridgeConnection.connectAsync({
        port: host.port,
        remoteHost: 'localhost',
      });
      connections.push(conn);

      expect(conn.role).toBe('client');
      expect(conn.isConnected).toBe(true);
    });

    it('extracts port from remoteHost when colon is present', async () => {
      host = await createMockHostAsync();

      const conn = await BridgeConnection.connectAsync({
        remoteHost: `localhost:${host.port}`,
      });
      connections.push(conn);

      expect(conn.role).toBe('client');
      expect(conn.isConnected).toBe(true);
    });
  });

  // -----------------------------------------------------------------------
  // Error handling
  // -----------------------------------------------------------------------

  describe('error handling', () => {
    it('throws clear error on ECONNREFUSED for remote host', async () => {
      await expect(
        BridgeConnection.connectAsync({
          remoteHost: 'localhost:19999',
        }),
      ).rejects.toThrow(
        /Could not connect to bridge host at localhost:19999/,
      );
    });

    it('includes helpful suggestion in ECONNREFUSED error', async () => {
      await expect(
        BridgeConnection.connectAsync({
          remoteHost: 'localhost:19998',
        }),
      ).rejects.toThrow(
        /studio-bridge serve/,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Client-only mode
  // -----------------------------------------------------------------------

  describe('client-only mode', () => {
    it('does not become host when remoteHost is specified', async () => {
      // When remoteHost is set but nothing is listening, it should
      // NOT fall back to host mode -- it should throw
      await expect(
        BridgeConnection.connectAsync({
          remoteHost: 'localhost:19997',
        }),
      ).rejects.toThrow();
    });

    it('remote client can list sessions from host', async () => {
      host = await createMockHostAsync();

      const conn = await BridgeConnection.connectAsync({
        remoteHost: `localhost:${host.port}`,
      });
      connections.push(conn);

      // No plugins connected, so sessions should be empty
      const sessions = conn.listSessions();
      expect(sessions).toEqual([]);
    });
  });

  // -----------------------------------------------------------------------
  // local option
  // -----------------------------------------------------------------------

  describe('local option', () => {
    it('local option is accepted without error', async () => {
      // local: true just skips devcontainer detection -- in a normal
      // environment it should behave like the default path (try bind)
      const conn = await BridgeConnection.connectAsync({
        port: 0,
        keepAlive: true,
        local: true,
      });
      connections.push(conn);

      // Should work normally in local mode
      expect(conn.isConnected).toBe(true);
    });
  });
});
