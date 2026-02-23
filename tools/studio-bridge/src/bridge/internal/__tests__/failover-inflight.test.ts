/**
 * Integration tests for inflight request handling during failover. Verifies
 * that pending requests are properly rejected when the client is disconnected,
 * and that old sessions throw SessionDisconnectedError after failover.
 *
 * Uses real BridgeClient connected to a mock host (WebSocketServer).
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocketServer, WebSocket } from 'ws';
import { BridgeClient } from '../bridge-client.js';
import {
  encodeHostMessage,
  decodeHostMessage,
  type HostProtocolMessage,
} from '../host-protocol.js';
import { SessionDisconnectedError } from '../../types.js';
import type { SessionInfo } from '../../types.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createSessionInfo(overrides: Partial<SessionInfo> = {}): SessionInfo {
  return {
    sessionId: 'session-1',
    placeName: 'TestPlace',
    state: 'Edit',
    pluginVersion: '1.0.0',
    capabilities: ['execute', 'queryState'],
    connectedAt: new Date('2024-01-01'),
    origin: 'user',
    context: 'edit',
    instanceId: 'inst-1',
    placeId: 100,
    gameId: 200,
    ...overrides,
  };
}

interface MockHost {
  wss: WebSocketServer;
  port: number;
  clients: WebSocket[];
  receivedMessages: HostProtocolMessage[];
}

async function createMockHostWithSessions(
  sessions: SessionInfo[],
): Promise<MockHost> {
  const clients: WebSocket[] = [];
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
    clients.push(ws);

    ws.on('message', (raw) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = decodeHostMessage(data);
      if (msg) {
        receivedMessages.push(msg);

        if (msg.type === 'list-sessions') {
          ws.send(encodeHostMessage({
            type: 'list-sessions-response',
            requestId: msg.requestId,
            sessions,
          }));
        }
        // Do NOT respond to host-envelope — leave them pending
      }
    });
  });

  return { wss, port, clients, receivedMessages };
}

async function closeHost(host: MockHost): Promise<void> {
  for (const client of host.wss.clients) {
    client.terminate();
  }
  await new Promise<void>((resolve) => {
    host.wss.close(() => resolve());
  });
}

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Inflight request handling during failover', () => {
  let host: MockHost | undefined;
  let client: BridgeClient | undefined;

  afterEach(async () => {
    if (client) {
      try { await client.disconnectAsync(); } catch { /* ignore */ }
      client = undefined;
    }
    if (host) {
      try { await closeHost(host); } catch { /* ignore */ }
      host = undefined;
    }
  });

  it('pending request rejects with error when client disconnects', async () => {
    const sessions = [createSessionInfo({ sessionId: 'session-1' })];
    host = await createMockHostWithSessions(sessions);

    client = new BridgeClient();
    await client.connectAsync(host.port);

    const session = client.getSession('session-1');
    expect(session).toBeDefined();

    // Send an action that will never get a response (mock host doesn't
    // respond to host-envelope messages)
    const execPromise = session!.execAsync('print("hello")', 30_000);

    // Wait for the envelope to be sent
    await delay(50);

    // Simulate failover cleanup by explicitly disconnecting
    await client.disconnectAsync();
    client = undefined;

    // The pending request should reject with 'Client disconnected'
    await expect(execPromise).rejects.toThrow('Client disconnected');
  });

  it('ALL pending requests are rejected, not just the first', async () => {
    const sessions = [createSessionInfo({ sessionId: 'session-1' })];
    host = await createMockHostWithSessions(sessions);

    client = new BridgeClient();
    await client.connectAsync(host.port);

    const session = client.getSession('session-1');
    expect(session).toBeDefined();

    // Send multiple actions that will never get responses
    const promises = [
      session!.execAsync('print("a")', 30_000),
      session!.execAsync('print("b")', 30_000),
      session!.execAsync('print("c")', 30_000),
    ];

    // Wait for envelopes to be sent
    await delay(50);

    // Simulate failover cleanup
    await client.disconnectAsync();
    client = undefined;

    // ALL promises should reject
    const results = await Promise.allSettled(promises);
    for (const result of results) {
      expect(result.status).toBe('rejected');
    }
    // All should reject with 'Client disconnected'
    for (const result of results) {
      if (result.status === 'rejected') {
        expect(result.reason.message).toContain('Client disconnected');
      }
    }
  });

  it('requests reject before takeover would complete', async () => {
    const sessions = [createSessionInfo({ sessionId: 'session-1' })];
    host = await createMockHostWithSessions(sessions);

    client = new BridgeClient();
    await client.connectAsync(host.port);

    const session = client.getSession('session-1');
    expect(session).toBeDefined();

    // Track ordering
    const events: string[] = [];

    // Start a pending request
    const execPromise = session!.execAsync('print("hello")', 30_000)
      .catch((err) => {
        events.push('request-rejected');
        throw err;
      });

    await delay(50);

    // Disconnect (which immediately rejects pending requests)
    await client.disconnectAsync();
    client = undefined;

    // Verify the promise rejected
    await expect(execPromise).rejects.toThrow();

    // Request rejection should have been recorded
    expect(events).toContain('request-rejected');
  });

  it('after failover, old BridgeSession throws SessionDisconnectedError', async () => {
    const sessions = [createSessionInfo({ sessionId: 'session-1' })];
    host = await createMockHostWithSessions(sessions);

    client = new BridgeClient();
    await client.connectAsync(host.port);

    const session = client.getSession('session-1');
    expect(session).toBeDefined();

    // Disconnect the client (simulates failover cleanup)
    await client.disconnectAsync();
    client = undefined;

    // The old session should now throw SessionDisconnectedError
    expect(session!.isConnected).toBe(false);
    await expect(session!.execAsync('print("hello")')).rejects.toThrow(SessionDisconnectedError);
    await expect(session!.queryStateAsync()).rejects.toThrow(SessionDisconnectedError);
    await expect(session!.captureScreenshotAsync()).rejects.toThrow(SessionDisconnectedError);
    await expect(session!.queryLogsAsync()).rejects.toThrow(SessionDisconnectedError);
    await expect(
      session!.queryDataModelAsync({ path: 'game' }),
    ).rejects.toThrow(SessionDisconnectedError);
    await expect(
      session!.subscribeAsync(['stateChange']),
    ).rejects.toThrow(SessionDisconnectedError);
    await expect(
      session!.unsubscribeAsync(['stateChange']),
    ).rejects.toThrow(SessionDisconnectedError);
  });

  it('client emits disconnected event when host dies', async () => {
    host = await createMockHostWithSessions([]);

    client = new BridgeClient();
    await client.connectAsync(host.port);

    const disconnectedPromise = new Promise<void>((resolve) => {
      client!.on('disconnected', resolve);
    });

    // Kill the host (force close)
    await closeHost(host);
    host = undefined;

    // Should emit disconnected
    await disconnectedPromise;
    expect(client.isConnected).toBe(false);
  });

  it('multiple pending requests from different sessions all reject', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 'session-a', instanceId: 'inst-a' }),
      createSessionInfo({ sessionId: 'session-b', instanceId: 'inst-b' }),
    ];
    host = await createMockHostWithSessions(sessions);

    client = new BridgeClient();
    await client.connectAsync(host.port);

    const sessionA = client.getSession('session-a');
    const sessionB = client.getSession('session-b');
    expect(sessionA).toBeDefined();
    expect(sessionB).toBeDefined();

    // Send actions on both sessions
    const promiseA = sessionA!.execAsync('print("a")', 30_000);
    const promiseB = sessionB!.execAsync('print("b")', 30_000);

    await delay(50);

    // Disconnect (simulating failover cleanup)
    await client.disconnectAsync();
    client = undefined;

    // Both should reject
    const results = await Promise.allSettled([promiseA, promiseB]);
    expect(results[0].status).toBe('rejected');
    expect(results[1].status).toBe('rejected');
  });

  it('session disconnected event fires when handles are marked disconnected', async () => {
    const sessions = [createSessionInfo({ sessionId: 'session-1' })];
    host = await createMockHostWithSessions(sessions);

    client = new BridgeClient();
    await client.connectAsync(host.port);

    const session = client.getSession('session-1');
    expect(session).toBeDefined();

    const disconnectedPromise = new Promise<void>((resolve) => {
      session!.on('disconnected', resolve);
    });

    // Disconnect the client
    await client.disconnectAsync();
    client = undefined;

    // Session should have emitted disconnected
    await disconnectedPromise;
    expect(session!.isConnected).toBe(false);
  });
});
