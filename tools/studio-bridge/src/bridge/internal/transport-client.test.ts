/**
 * Unit tests for TransportClient -- validates connection, message
 * send/receive, disconnect handling, and reconnection with backoff.
 */

import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { WebSocketServer, WebSocket } from 'ws';
import { TransportClient } from './transport-client.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function createTestServer(): Promise<{
  wss: WebSocketServer;
  port: number;
  connections: WebSocket[];
}> {
  const connections: WebSocket[] = [];
  const wss = new WebSocketServer({ port: 0 });

  const port = await new Promise<number>((resolve) => {
    wss.on('listening', () => {
      const addr = wss.address();
      if (typeof addr === 'object' && addr !== null) {
        resolve(addr.port);
      }
    });
  });

  wss.on('connection', (ws) => {
    connections.push(ws);
  });

  return { wss, port, connections };
}

async function closeServer(wss: WebSocketServer): Promise<void> {
  for (const client of wss.clients) {
    client.terminate();
  }
  await new Promise<void>((resolve) => {
    wss.close(() => resolve());
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('TransportClient', () => {
  let server: { wss: WebSocketServer; port: number; connections: WebSocket[] } | undefined;
  let client: TransportClient | undefined;

  afterEach(async () => {
    if (client) {
      client.disconnect();
      client = undefined;
    }
    if (server) {
      await closeServer(server.wss);
      server = undefined;
    }
  });

  // -----------------------------------------------------------------------
  // Connection
  // -----------------------------------------------------------------------

  describe('connectAsync', () => {
    it('connects to a WebSocket server', async () => {
      server = await createTestServer();
      client = new TransportClient();

      await client.connectAsync(`ws://localhost:${server.port}`);

      expect(client.isConnected).toBe(true);
    });

    it('rejects when server is not available', async () => {
      client = new TransportClient();

      await expect(
        client.connectAsync('ws://localhost:19999'),
      ).rejects.toThrow();
    });

    it('emits connected event', async () => {
      server = await createTestServer();
      client = new TransportClient();
      const listener = vi.fn();

      client.on('connected', listener);
      await client.connectAsync(`ws://localhost:${server.port}`);

      expect(listener).toHaveBeenCalledTimes(1);
    });
  });

  // -----------------------------------------------------------------------
  // Messaging
  // -----------------------------------------------------------------------

  describe('send and receive', () => {
    it('sends a message to the server', async () => {
      server = await createTestServer();
      client = new TransportClient();
      await client.connectAsync(`ws://localhost:${server.port}`);

      // Wait for server to register the connection
      await new Promise((r) => setTimeout(r, 50));

      const received = new Promise<string>((resolve) => {
        server!.connections[0].on('message', (raw) => {
          resolve(typeof raw === 'string' ? raw : raw.toString('utf-8'));
        });
      });

      client.send('hello-server');

      expect(await received).toBe('hello-server');
    });

    it('receives messages from the server', async () => {
      server = await createTestServer();
      client = new TransportClient();
      await client.connectAsync(`ws://localhost:${server.port}`);

      await new Promise((r) => setTimeout(r, 50));

      const received = new Promise<string>((resolve) => {
        client!.on('message', resolve);
      });

      server.connections[0].send('hello-client');

      expect(await received).toBe('hello-client');
    });

    it('throws when sending on a disconnected client', async () => {
      client = new TransportClient();

      expect(() => client!.send('test')).toThrow('TransportClient is not connected');
    });
  });

  // -----------------------------------------------------------------------
  // Disconnect
  // -----------------------------------------------------------------------

  describe('disconnect', () => {
    it('disconnects cleanly', async () => {
      server = await createTestServer();
      client = new TransportClient();
      await client.connectAsync(`ws://localhost:${server.port}`);

      client.disconnect();

      expect(client.isConnected).toBe(false);
    });

    it('emits disconnected event', async () => {
      server = await createTestServer();
      client = new TransportClient();
      await client.connectAsync(`ws://localhost:${server.port}`);

      const listener = vi.fn();
      client.on('disconnected', listener);

      client.disconnect();

      expect(listener).toHaveBeenCalledTimes(1);
    });

    it('emits disconnected when server closes connection', async () => {
      server = await createTestServer();
      client = new TransportClient();
      await client.connectAsync(`ws://localhost:${server.port}`, {
        maxReconnectAttempts: 0,
      });

      // Suppress the unhandled error event from reconnection failure
      client.on('error', () => {});

      await new Promise((r) => setTimeout(r, 50));

      const disconnected = new Promise<void>((resolve) => {
        client!.on('disconnected', resolve);
      });

      // Close from server side
      server.connections[0].close();

      await disconnected;
      expect(client.isConnected).toBe(false);
    });
  });

  // -----------------------------------------------------------------------
  // Reconnection
  // -----------------------------------------------------------------------

  describe('reconnection', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it('attempts reconnection after server-initiated disconnect', async () => {
      vi.useRealTimers(); // Need real timers for initial connect

      server = await createTestServer();
      client = new TransportClient();
      await client.connectAsync(`ws://localhost:${server.port}`, {
        maxReconnectAttempts: 3,
        initialBackoffMs: 100,
        maxBackoffMs: 1000,
      });

      await new Promise((r) => setTimeout(r, 50));

      // Disconnect from server side
      server.connections[0].close();

      // Wait for disconnect to register
      await new Promise((r) => setTimeout(r, 50));
      expect(client.isConnected).toBe(false);

      // Wait for first reconnection attempt (100ms backoff)
      await new Promise((r) => setTimeout(r, 200));

      // Client should reconnect
      expect(client.isConnected).toBe(true);
    });

    it('does not reconnect after intentional disconnect', async () => {
      vi.useRealTimers();

      server = await createTestServer();
      client = new TransportClient();
      await client.connectAsync(`ws://localhost:${server.port}`, {
        maxReconnectAttempts: 3,
        initialBackoffMs: 50,
      });

      const errorListener = vi.fn();
      client.on('error', errorListener);

      client.disconnect();

      // Wait well past the backoff
      await new Promise((r) => setTimeout(r, 200));

      // Should not have tried to reconnect (no error events from failed reconnects)
      expect(client.isConnected).toBe(false);
    });
  });
});
