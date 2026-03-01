/**
 * Integration tests for host<->client protocol. Verifies that a real
 * BridgeHost correctly processes client WebSocket messages (list-sessions,
 * list-instances) and broadcasts session events when plugins connect or
 * disconnect. This covers Bug 1: host never processed client messages.
 *
 * Uses real BridgeHost and WebSocket connections — no mocks for the host side.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { EventEmitter } from 'events';
import { WebSocket } from 'ws';
import { BridgeHost } from '../bridge-host.js';
import { SessionTracker } from '../session-tracker.js';
import {
  encodeHostMessage,
  decodeHostMessage,
  type HostProtocolMessage,
  type ListSessionsRequest,
  type ListInstancesRequest,
} from '../host-protocol.js';
import type { Capability } from '../../../server/web-socket-protocol.js';
import type { SessionInfo, SessionContext } from '../../types.js';

// ---------------------------------------------------------------------------
// Stub transport handle (mirrors HostStubTransportHandle in bridge-connection)
// ---------------------------------------------------------------------------

class StubTransportHandle extends EventEmitter {
  get isConnected(): boolean {
    return true;
  }

  async sendActionAsync(): Promise<never> {
    throw new Error('stub');
  }

  sendMessage(): void {
    // no-op
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function connectClientWsAsync(port: number): Promise<WebSocket> {
  return new Promise<WebSocket>((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/client`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function connectPluginWsAsync(port: number): Promise<WebSocket> {
  return new Promise<WebSocket>((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/plugin`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

async function waitForMessageAsync(
  ws: WebSocket,
  timeoutMs = 2_000,
): Promise<HostProtocolMessage> {
  return new Promise<HostProtocolMessage>((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Timed out waiting for message (${timeoutMs}ms)`));
    }, timeoutMs);

    ws.once('message', (raw) => {
      clearTimeout(timer);
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = decodeHostMessage(data);
      if (!msg) {
        reject(new Error(`Failed to decode host message: ${data}`));
        return;
      }
      resolve(msg);
    });
  });
}

function deriveContext(state: string): SessionContext {
  if (state === 'Server') return 'server';
  if (state === 'Client') return 'client';
  return 'edit';
}

/**
 * Wire BridgeHost events to a SessionTracker, mirroring the pattern from
 * BridgeConnection._initHostAsync. Returns the tracker for querying.
 */
function wireHostAndTracker(host: BridgeHost): SessionTracker {
  const tracker = new SessionTracker();

  // plugin-connected -> tracker.addSession
  host.on('plugin-connected', (info) => {
    const state = info.state ?? 'Edit';
    const context = deriveContext(state);

    const sessionInfo: SessionInfo = {
      sessionId: info.sessionId,
      placeName: info.placeName ?? '',
      placeFile: info.placeFile,
      state: state as SessionInfo['state'],
      pluginVersion: info.pluginVersion ?? '',
      capabilities: info.capabilities,
      connectedAt: new Date(),
      origin: 'user',
      context,
      instanceId: info.instanceId ?? info.sessionId,
      placeId: 0,
      gameId: 0,
    };

    const handle = new StubTransportHandle();
    tracker.addSession(info.sessionId, sessionInfo, handle);
  });

  // plugin-disconnected -> tracker.removeSession
  host.on('plugin-disconnected', (sessionId: string) => {
    tracker.removeSession(sessionId);
  });

  // client-message -> respond to list-sessions, list-instances
  host.on(
    'client-message',
    (msg: HostProtocolMessage, reply: (m: HostProtocolMessage) => void) => {
      if (msg.type === 'list-sessions') {
        const req = msg as ListSessionsRequest;
        reply({
          type: 'list-sessions-response',
          requestId: req.requestId,
          sessions: tracker.listSessions(),
        });
      } else if (msg.type === 'list-instances') {
        const req = msg as ListInstancesRequest;
        reply({
          type: 'list-instances-response',
          requestId: req.requestId,
          instances: tracker.listInstances(),
        });
      }
    },
  );

  // session-added -> broadcast session-event connected
  tracker.on('session-added', (tracked: { info: SessionInfo }) => {
    host.broadcastToClients({
      type: 'session-event',
      event: 'connected',
      sessionId: tracked.info.sessionId,
      session: tracked.info,
      context: tracked.info.context,
      instanceId: tracked.info.instanceId,
    });
  });

  // session-removed -> broadcast session-event disconnected
  tracker.on('session-removed', (sessionId: string) => {
    host.broadcastToClients({
      type: 'session-event',
      event: 'disconnected',
      sessionId,
      context: 'edit',
      instanceId: sessionId,
    });
  });

  return tracker;
}

/**
 * Send a v2 register message on a plugin WebSocket and wait for the welcome.
 */
async function registerPluginAsync(
  pluginWs: WebSocket,
  options: {
    sessionId: string;
    instanceId: string;
    placeName?: string;
    pluginVersion?: string;
    state?: string;
    capabilities?: Capability[];
  },
): Promise<void> {
  const welcomePromise = new Promise<void>((resolve) => {
    pluginWs.once('message', () => resolve());
  });

  pluginWs.send(
    JSON.stringify({
      type: 'register',
      sessionId: options.sessionId,
      protocolVersion: 2,
      payload: {
        pluginVersion: options.pluginVersion ?? '0.7.0',
        instanceId: options.instanceId,
        placeName: options.placeName ?? 'TestPlace',
        state: options.state ?? 'Edit',
        capabilities: options.capabilities ?? ['execute'],
      },
    }),
  );

  await welcomePromise;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Host-client integration', { timeout: 10_000 }, () => {
  let host: BridgeHost | undefined;
  const openSockets: WebSocket[] = [];

  afterEach(async () => {
    for (const ws of openSockets) {
      if (
        ws.readyState === WebSocket.OPEN ||
        ws.readyState === WebSocket.CONNECTING
      ) {
        ws.terminate();
      }
    }
    openSockets.length = 0;

    if (host) {
      try {
        await host.stopAsync();
      } catch {
        /* ignore */
      }
      host = undefined;
    }
  });

  // -------------------------------------------------------------------------
  // Test 1: list-sessions
  // -------------------------------------------------------------------------

  it('host responds to list-sessions request from client WebSocket', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });
    wireHostAndTracker(host);

    const clientWs = await connectClientWsAsync(port);
    openSockets.push(clientWs);

    // Send list-sessions request
    const responsePromise = waitForMessageAsync(clientWs);
    clientWs.send(
      encodeHostMessage({
        type: 'list-sessions',
        requestId: 'req-1',
      }),
    );

    const response = await responsePromise;

    expect(response.type).toBe('list-sessions-response');
    expect(response).toHaveProperty('requestId', 'req-1');
    expect(response).toHaveProperty('sessions');
    expect((response as { sessions: unknown[] }).sessions).toEqual([]);
  });

  // -------------------------------------------------------------------------
  // Test 2: list-instances
  // -------------------------------------------------------------------------

  it('host responds to list-instances request from client WebSocket', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });
    wireHostAndTracker(host);

    const clientWs = await connectClientWsAsync(port);
    openSockets.push(clientWs);

    // Send list-instances request
    const responsePromise = waitForMessageAsync(clientWs);
    clientWs.send(
      encodeHostMessage({
        type: 'list-instances',
        requestId: 'req-2',
      }),
    );

    const response = await responsePromise;

    expect(response.type).toBe('list-instances-response');
    expect(response).toHaveProperty('requestId', 'req-2');
    expect(response).toHaveProperty('instances');
    expect((response as { instances: unknown[] }).instances).toEqual([]);
  });

  // -------------------------------------------------------------------------
  // Test 3: session-event connected when plugin connects
  // -------------------------------------------------------------------------

  it('client WebSocket receives session-event when plugin connects', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });
    wireHostAndTracker(host);

    // Connect a client first so it can receive the broadcast
    const clientWs = await connectClientWsAsync(port);
    openSockets.push(clientWs);

    // Set up listener before plugin connects
    const eventPromise = waitForMessageAsync(clientWs);

    // Connect a plugin and register
    const pluginWs = await connectPluginWsAsync(port);
    openSockets.push(pluginWs);

    await registerPluginAsync(pluginWs, {
      sessionId: 'test-session-1',
      instanceId: 'game-123',
      placeName: 'TestPlace',
      pluginVersion: '0.7.0',
      state: 'Edit',
      capabilities: ['execute'],
    });

    const event = await eventPromise;

    expect(event.type).toBe('session-event');
    expect(event).toHaveProperty('event', 'connected');
    expect(event).toHaveProperty('sessionId', 'test-session-1');
  });

  // -------------------------------------------------------------------------
  // Test 4: session-event disconnected when plugin disconnects
  // -------------------------------------------------------------------------

  it('client WebSocket receives session-event when plugin disconnects', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });
    wireHostAndTracker(host);

    const clientWs = await connectClientWsAsync(port);
    openSockets.push(clientWs);

    // Connect and register a plugin
    const pluginWs = await connectPluginWsAsync(port);
    openSockets.push(pluginWs);

    // Wait for the connected event first
    const connectedPromise = waitForMessageAsync(clientWs);

    await registerPluginAsync(pluginWs, {
      sessionId: 'test-session-1',
      instanceId: 'game-123',
    });

    await connectedPromise;

    // Now set up listener for the disconnected event
    const disconnectPromise = waitForMessageAsync(clientWs);

    // Close the plugin WebSocket
    pluginWs.close();

    const event = await disconnectPromise;

    expect(event.type).toBe('session-event');
    expect(event).toHaveProperty('event', 'disconnected');
    expect(event).toHaveProperty('sessionId', 'test-session-1');
  });

  // -------------------------------------------------------------------------
  // Test 5: list-sessions returns connected plugin after register
  // -------------------------------------------------------------------------

  it('list-sessions returns connected plugin after register', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });
    wireHostAndTracker(host);

    const clientWs = await connectClientWsAsync(port);
    openSockets.push(clientWs);

    // Connect and register a plugin
    const pluginWs = await connectPluginWsAsync(port);
    openSockets.push(pluginWs);

    // Wait for the connected session-event so we know the tracker has the session
    const connectedPromise = waitForMessageAsync(clientWs);

    await registerPluginAsync(pluginWs, {
      sessionId: 'test-session-1',
      instanceId: 'game-123',
      placeName: 'TestPlace',
      pluginVersion: '0.7.0',
      state: 'Edit',
      capabilities: ['execute'],
    });

    await connectedPromise;

    // Now send list-sessions
    const responsePromise = waitForMessageAsync(clientWs);
    clientWs.send(
      encodeHostMessage({
        type: 'list-sessions',
        requestId: 'req-ls-1',
      }),
    );

    const response = await responsePromise;

    expect(response.type).toBe('list-sessions-response');
    expect(response).toHaveProperty('requestId', 'req-ls-1');

    const sessions = (response as { sessions: SessionInfo[] }).sessions;
    expect(sessions).toHaveLength(1);
    expect(sessions[0].sessionId).toBe('test-session-1');
    expect(sessions[0].instanceId).toBe('game-123');
    expect(sessions[0].placeName).toBe('TestPlace');
  });
});
