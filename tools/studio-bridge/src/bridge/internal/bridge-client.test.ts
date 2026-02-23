/**
 * Unit tests for BridgeClient -- validates connection to a mock host,
 * session listing, action forwarding via HostEnvelope, and session
 * event handling.
 */

import { describe, it, expect, vi, afterEach } from 'vitest';
import { WebSocketServer, WebSocket } from 'ws';
import { BridgeClient } from './bridge-client.js';
import {
  encodeHostMessage,
  decodeHostMessage,
  type HostEnvelope,
  type ListSessionsRequest,
  type HostProtocolMessage,
} from './host-protocol.js';
import type { SessionInfo } from '../types.js';

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

async function createMockHost(): Promise<MockHost> {
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

  return { wss, port, clients, receivedMessages };
}

async function createMockHostWithSessions(
  sessions: SessionInfo[],
): Promise<MockHost> {
  const host = await createMockHost();

  // Override the message handler to respond with sessions
  const originalConnection = host.wss.listeners('connection');
  host.wss.removeAllListeners('connection');

  host.wss.on('connection', (ws) => {
    host.clients.push(ws);

    ws.on('message', (raw) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = decodeHostMessage(data);
      if (msg) {
        host.receivedMessages.push(msg);

        if (msg.type === 'list-sessions') {
          ws.send(encodeHostMessage({
            type: 'list-sessions-response',
            requestId: msg.requestId,
            sessions,
          }));
        }
      }
    });
  });

  return host;
}

async function closeHost(host: MockHost): Promise<void> {
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

describe('BridgeClient', () => {
  let host: MockHost | undefined;
  let client: BridgeClient | undefined;

  afterEach(async () => {
    if (client) {
      await client.disconnectAsync();
      client = undefined;
    }
    if (host) {
      await closeHost(host);
      host = undefined;
    }
  });

  // -----------------------------------------------------------------------
  // Connection
  // -----------------------------------------------------------------------

  describe('connectAsync', () => {
    it('connects to a mock host', async () => {
      host = await createMockHost();
      client = new BridgeClient();

      await client.connectAsync(host.port);

      expect(client.isConnected).toBe(true);
    });

    it('sends list-sessions request on connect', async () => {
      host = await createMockHost();
      client = new BridgeClient();

      await client.connectAsync(host.port);

      // Wait for message processing
      await new Promise((r) => setTimeout(r, 50));

      const listReqs = host.receivedMessages.filter((m) => m.type === 'list-sessions');
      expect(listReqs.length).toBeGreaterThanOrEqual(1);
    });
  });

  // -----------------------------------------------------------------------
  // Session listing
  // -----------------------------------------------------------------------

  describe('listSessions', () => {
    it('returns empty list when host has no sessions', async () => {
      host = await createMockHost();
      client = new BridgeClient();

      await client.connectAsync(host.port);

      expect(client.listSessions()).toEqual([]);
    });

    it('returns sessions from host response', async () => {
      const sessions = [
        createSessionInfo({ sessionId: 'session-a' }),
        createSessionInfo({ sessionId: 'session-b', instanceId: 'inst-2' }),
      ];

      host = await createMockHostWithSessions(sessions);
      client = new BridgeClient();

      await client.connectAsync(host.port);

      const listed = client.listSessions();
      expect(listed).toHaveLength(2);
      expect(listed.map((s) => s.sessionId).sort()).toEqual(['session-a', 'session-b']);
    });
  });

  // -----------------------------------------------------------------------
  // Instance listing
  // -----------------------------------------------------------------------

  describe('listInstances', () => {
    it('derives instances from sessions', async () => {
      const sessions = [
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        createSessionInfo({ sessionId: 's-server', instanceId: 'inst-A', context: 'server' }),
      ];

      host = await createMockHostWithSessions(sessions);
      client = new BridgeClient();

      await client.connectAsync(host.port);

      const instances = client.listInstances();
      expect(instances).toHaveLength(1);
      expect(instances[0].instanceId).toBe('inst-A');
      expect(instances[0].contexts.sort()).toEqual(['edit', 'server']);
    });
  });

  // -----------------------------------------------------------------------
  // Session access
  // -----------------------------------------------------------------------

  describe('getSession', () => {
    it('returns a BridgeSession for a known session', async () => {
      const sessions = [createSessionInfo({ sessionId: 'session-x' })];
      host = await createMockHostWithSessions(sessions);
      client = new BridgeClient();

      await client.connectAsync(host.port);

      const session = client.getSession('session-x');
      expect(session).toBeDefined();
      expect(session!.info.sessionId).toBe('session-x');
    });

    it('returns undefined for unknown session', async () => {
      host = await createMockHost();
      client = new BridgeClient();

      await client.connectAsync(host.port);

      expect(client.getSession('nonexistent')).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Action forwarding
  // -----------------------------------------------------------------------

  describe('action forwarding', () => {
    it('sends HostEnvelope for session actions', async () => {
      const sessions = [createSessionInfo({ sessionId: 'session-1' })];
      host = await createMockHostWithSessions(sessions);

      // Override host to respond to envelopes
      host.wss.removeAllListeners('connection');
      host.wss.on('connection', (ws) => {
        host!.clients.push(ws);

        ws.on('message', (raw) => {
          const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
          const msg = decodeHostMessage(data);
          if (!msg) return;

          host!.receivedMessages.push(msg);

          if (msg.type === 'list-sessions') {
            ws.send(encodeHostMessage({
              type: 'list-sessions-response',
              requestId: msg.requestId,
              sessions,
            }));
          }

          if (msg.type === 'host-envelope') {
            // Respond with a host response
            ws.send(encodeHostMessage({
              type: 'host-response',
              requestId: msg.requestId,
              result: {
                type: 'stateResult',
                sessionId: 'session-1',
                requestId: msg.requestId,
                payload: {
                  state: 'Edit',
                  placeId: 100,
                  placeName: 'TestPlace',
                  gameId: 200,
                },
              },
            }));
          }
        });
      });

      client = new BridgeClient();
      await client.connectAsync(host.port);

      const session = client.getSession('session-1');
      expect(session).toBeDefined();

      const result = await session!.queryStateAsync();

      expect(result.state).toBe('Edit');
      expect(result.placeId).toBe(100);

      // Verify that a host-envelope was sent
      const envelopes = host.receivedMessages.filter((m) => m.type === 'host-envelope');
      expect(envelopes.length).toBeGreaterThanOrEqual(1);
    });
  });

  // -----------------------------------------------------------------------
  // Session events
  // -----------------------------------------------------------------------

  describe('session events', () => {
    it('handles session-connected event from host', async () => {
      host = await createMockHost();
      client = new BridgeClient();

      await client.connectAsync(host.port);

      // Wait for client to be fully set up
      await new Promise((r) => setTimeout(r, 50));

      const connectedPromise = new Promise<string>((resolve) => {
        client!.on('session-connected', (session: any) => {
          resolve(session.info.sessionId);
        });
      });

      // Host broadcasts a session-connected event
      host.clients[0].send(encodeHostMessage({
        type: 'session-event',
        event: 'connected',
        session: createSessionInfo({ sessionId: 'new-session' }),
        sessionId: 'new-session',
        context: 'edit',
        instanceId: 'inst-1',
      }));

      const sessionId = await connectedPromise;
      expect(sessionId).toBe('new-session');
      expect(client.listSessions()).toHaveLength(1);
    });

    it('handles session-disconnected event from host', async () => {
      const sessions = [createSessionInfo({ sessionId: 'session-1' })];
      host = await createMockHostWithSessions(sessions);
      client = new BridgeClient();

      await client.connectAsync(host.port);
      expect(client.listSessions()).toHaveLength(1);

      const disconnectedPromise = new Promise<string>((resolve) => {
        client!.on('session-disconnected', resolve);
      });

      // Wait for client to be fully set up
      await new Promise((r) => setTimeout(r, 50));

      // Host broadcasts a session-disconnected event
      host.clients[0].send(encodeHostMessage({
        type: 'session-event',
        event: 'disconnected',
        sessionId: 'session-1',
        context: 'edit',
        instanceId: 'inst-1',
      }));

      const sessionId = await disconnectedPromise;
      expect(sessionId).toBe('session-1');
      expect(client.listSessions()).toHaveLength(0);
    });
  });

  // -----------------------------------------------------------------------
  // Disconnect
  // -----------------------------------------------------------------------

  describe('disconnectAsync', () => {
    it('disconnects and clears state', async () => {
      const sessions = [createSessionInfo()];
      host = await createMockHostWithSessions(sessions);
      client = new BridgeClient();

      await client.connectAsync(host.port);
      expect(client.listSessions()).toHaveLength(1);

      await client.disconnectAsync();

      expect(client.isConnected).toBe(false);
      expect(client.listSessions()).toHaveLength(0);
    });
  });
});
