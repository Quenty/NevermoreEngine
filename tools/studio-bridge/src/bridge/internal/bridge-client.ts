/**
 * Bridge client that connects to an existing bridge host. From the
 * consumer's perspective it behaves identically to being the host --
 * actions are forwarded through the host rather than delivered directly
 * to plugins.
 *
 * The client:
 * - Connects to ws://host:port/client using TransportClient
 * - Sends ListSessionsRequest on connect to populate local session cache
 * - Listens for SessionEvent messages from host to keep cache in sync
 * - Creates BridgeSession instances backed by RelayedTransportHandle
 */

import { EventEmitter } from 'events';
import { randomUUID } from 'crypto';
import { TransportClient, type TransportClientOptions } from './transport-client.js';
import {
  encodeHostMessage,
  decodeHostMessage,
  type HostEnvelope,
  type HostResponse,
  type ListSessionsRequest,
  type ListSessionsResponse,
  type ListInstancesRequest,
  type ListInstancesResponse,
  type SessionEvent,
  type HostProtocolMessage,
  type HostTransferNotice,
} from './host-protocol.js';
import { HandOffManager } from './hand-off.js';
import type { TransportHandle } from './session-tracker.js';
import { BridgeSession } from '../bridge-session.js';
import type { SessionInfo, InstanceInfo, SessionContext } from '../types.js';
import type { PluginMessage, ServerMessage } from '../../server/web-socket-protocol.js';

// ---------------------------------------------------------------------------
// RelayedTransportHandle
// ---------------------------------------------------------------------------

/**
 * A TransportHandle that wraps actions in HostEnvelope messages and sends
 * them through the bridge host. Waits for the matching HostResponse.
 */
class RelayedTransportHandle extends EventEmitter implements TransportHandle {
  private _sessionId: string;
  private _client: BridgeClient;
  private _connected = true;

  constructor(sessionId: string, client: BridgeClient) {
    super();
    this._sessionId = sessionId;
    this._client = client;
  }

  async sendActionAsync<TResponse>(message: ServerMessage, timeoutMs: number): Promise<TResponse> {
    return this._client.sendEnvelopeAsync(this._sessionId, message, timeoutMs) as Promise<TResponse>;
  }

  sendMessage(message: ServerMessage): void {
    const requestId = randomUUID();
    const envelope: HostEnvelope = {
      type: 'host-envelope',
      requestId,
      targetSessionId: this._sessionId,
      action: message,
    };
    this._client.sendRaw(encodeHostMessage(envelope));
  }

  get isConnected(): boolean {
    return this._connected && this._client.isConnected;
  }

  markDisconnected(): void {
    this._connected = false;
    this.emit('disconnected');
  }
}

// ---------------------------------------------------------------------------
// BridgeClient
// ---------------------------------------------------------------------------

export class BridgeClient extends EventEmitter {
  private _transport = new TransportClient();
  private _sessions = new Map<string, SessionInfo>();
  private _sessionHandles = new Map<string, RelayedTransportHandle>();
  private _bridgeSessions = new Map<string, BridgeSession>();
  private _pendingRequests = new Map<string, {
    resolve: (value: PluginMessage) => void;
    reject: (error: Error) => void;
    timer: ReturnType<typeof setTimeout>;
  }>();
  private _isConnected = false;
  private _handOff: HandOffManager | undefined;

  /**
   * Connect to an existing bridge host.
   */
  async connectAsync(port: number, host?: string): Promise<void> {
    const targetHost = host ?? 'localhost';
    const url = `ws://${targetHost}:${port}/client`;

    this._handOff = new HandOffManager({ port });

    this._transport.on('message', (data: string) => {
      this._handleMessage(data);
    });

    this._transport.on('disconnected', () => {
      this._isConnected = false;
      this.emit('disconnected');

      // Trigger failover detection
      this._handleHostDisconnectAsync();
    });

    this._transport.on('connected', () => {
      this._isConnected = true;
      this.emit('connected');
    });

    await this._transport.connectAsync(url, {
      maxReconnectAttempts: 10,
      initialBackoffMs: 1_000,
      maxBackoffMs: 30_000,
    });

    this._isConnected = true;

    // Fetch initial session list from host
    await this._fetchSessionsAsync();
  }

  /**
   * Disconnect from the bridge host.
   */
  async disconnectAsync(): Promise<void> {
    this._transport.disconnect();
    this._isConnected = false;

    // Cancel all pending requests
    for (const [requestId, entry] of this._pendingRequests) {
      clearTimeout(entry.timer);
      entry.reject(new Error('Client disconnected'));
    }
    this._pendingRequests.clear();

    // Mark all handles as disconnected
    for (const handle of this._sessionHandles.values()) {
      handle.markDisconnected();
    }
    this._sessions.clear();
    this._sessionHandles.clear();
    this._bridgeSessions.clear();
  }

  /**
   * List all known sessions.
   */
  listSessions(): SessionInfo[] {
    return Array.from(this._sessions.values());
  }

  /**
   * List unique instances derived from session data.
   */
  listInstances(): InstanceInfo[] {
    const instanceMap = new Map<string, {
      info: SessionInfo;
      contexts: SessionContext[];
    }>();

    for (const session of this._sessions.values()) {
      const existing = instanceMap.get(session.instanceId);
      if (existing) {
        existing.contexts.push(session.context);
      } else {
        instanceMap.set(session.instanceId, {
          info: session,
          contexts: [session.context],
        });
      }
    }

    return Array.from(instanceMap.entries()).map(([instanceId, data]) => ({
      instanceId,
      placeName: data.info.placeName,
      placeId: data.info.placeId,
      gameId: data.info.gameId,
      contexts: data.contexts,
      origin: data.info.origin,
    }));
  }

  /**
   * Get a BridgeSession for a specific session ID.
   */
  getSession(sessionId: string): BridgeSession | undefined {
    return this._bridgeSessions.get(sessionId);
  }

  /** Whether the client is connected to the host. */
  get isConnected(): boolean {
    return this._isConnected;
  }

  // -------------------------------------------------------------------------
  // Internal: used by RelayedTransportHandle
  // -------------------------------------------------------------------------

  /**
   * Send an action wrapped in a HostEnvelope and wait for the response.
   */
  async sendEnvelopeAsync(
    targetSessionId: string,
    action: ServerMessage,
    timeoutMs: number,
  ): Promise<PluginMessage> {
    const requestId = randomUUID();

    const envelope: HostEnvelope = {
      type: 'host-envelope',
      requestId,
      targetSessionId,
      action,
    };

    return new Promise<PluginMessage>((resolve, reject) => {
      const timer = setTimeout(() => {
        this._pendingRequests.delete(requestId);
        reject(new Error(`Request "${requestId}" timed out after ${timeoutMs}ms`));
      }, timeoutMs);

      this._pendingRequests.set(requestId, { resolve, reject, timer });

      try {
        this._transport.send(encodeHostMessage(envelope));
      } catch (err) {
        this._pendingRequests.delete(requestId);
        clearTimeout(timer);
        reject(err);
      }
    });
  }

  /**
   * Send a raw string over the transport.
   */
  sendRaw(data: string): void {
    this._transport.send(data);
  }

  // -------------------------------------------------------------------------
  // Private
  // -------------------------------------------------------------------------

  private _handleMessage(data: string): void {
    const msg = decodeHostMessage(data);
    if (!msg) {
      return;
    }

    switch (msg.type) {
      case 'host-response':
        this._handleHostResponse(msg);
        break;

      case 'list-sessions-response':
        this._handleListSessionsResponse(msg);
        break;

      case 'list-instances-response':
        this._handleListInstancesResponse(msg);
        break;

      case 'session-event':
        this._handleSessionEvent(msg);
        break;

      case 'host-transfer':
        this._handOff?.onHostTransferNotice();
        break;
    }
  }

  private _handleHostResponse(msg: HostResponse): void {
    const pending = this._pendingRequests.get(msg.requestId);
    if (pending) {
      clearTimeout(pending.timer);
      this._pendingRequests.delete(msg.requestId);
      pending.resolve(msg.result);
    }

    // Also forward to the appropriate session handle for push messages
    const result = msg.result;
    if (result && typeof result === 'object' && 'sessionId' in result) {
      const sessionId = (result as any).sessionId;
      const handle = this._sessionHandles.get(sessionId);
      if (handle) {
        handle.emit('message', result);
      }
    }
  }

  private _handleListSessionsResponse(msg: ListSessionsResponse): void {
    const pending = this._pendingRequests.get(msg.requestId);
    if (pending) {
      clearTimeout(pending.timer);
      this._pendingRequests.delete(msg.requestId);
      // We handle this specially -- populate the cache
      for (const session of msg.sessions) {
        this._addSessionFromInfo(session);
      }
      // Resolve with a synthetic message (the caller only cares about the list)
      pending.resolve({
        type: 'subscribeResult',
        sessionId: '',
        requestId: msg.requestId,
        payload: { events: [] },
      } as PluginMessage);
    }
  }

  private _handleListInstancesResponse(_msg: ListInstancesResponse): void {
    // Instances are derived from sessions, so this is informational
  }

  private _handleSessionEvent(msg: SessionEvent): void {
    switch (msg.event) {
      case 'connected': {
        if (msg.session) {
          this._addSessionFromInfo(msg.session);
          const bridgeSession = this._bridgeSessions.get(msg.sessionId);
          if (bridgeSession) {
            this.emit('session-connected', bridgeSession);
          }
        }
        break;
      }

      case 'disconnected': {
        const handle = this._sessionHandles.get(msg.sessionId);
        if (handle) {
          handle.markDisconnected();
        }
        this._sessions.delete(msg.sessionId);
        this._sessionHandles.delete(msg.sessionId);
        this._bridgeSessions.delete(msg.sessionId);
        this.emit('session-disconnected', msg.sessionId);
        break;
      }

      case 'state-changed': {
        if (msg.session) {
          const existing = this._sessions.get(msg.sessionId);
          if (existing) {
            this._sessions.set(msg.sessionId, msg.session);
          }
        }
        break;
      }
    }
  }

  private _addSessionFromInfo(info: SessionInfo): void {
    this._sessions.set(info.sessionId, info);

    if (!this._sessionHandles.has(info.sessionId)) {
      const handle = new RelayedTransportHandle(info.sessionId, this);
      this._sessionHandles.set(info.sessionId, handle);
      this._bridgeSessions.set(info.sessionId, new BridgeSession(info, handle));
    }
  }

  private async _fetchSessionsAsync(): Promise<void> {
    const requestId = randomUUID();
    const request: ListSessionsRequest = {
      type: 'list-sessions',
      requestId,
    };

    return new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        this._pendingRequests.delete(requestId);
        reject(new Error('Timed out waiting for session list'));
      }, 5_000);

      this._pendingRequests.set(requestId, {
        resolve: () => {
          resolve();
        },
        reject,
        timer,
      });

      try {
        this._transport.send(encodeHostMessage(request));
      } catch (err) {
        this._pendingRequests.delete(requestId);
        clearTimeout(timer);
        reject(err);
      }
    });
  }

  /**
   * Handle host WebSocket disconnect by running the failover state machine.
   * Emits 'host-promoted' if this client should become the new host, or
   * 'host-fallback' if another client won the race, or 'host-unreachable'
   * if all retries are exhausted.
   */
  private async _handleHostDisconnectAsync(): Promise<void> {
    if (!this._handOff) {
      return;
    }

    console.warn('Bridge host disconnected. Attempting recovery...');

    try {
      const outcome = await this._handOff.onHostDisconnectedAsync();

      if (outcome === 'promoted') {
        this.emit('host-promoted');
      } else {
        this.emit('host-fallback');
      }
    } catch {
      // HostUnreachableError — nothing we can do
      this.emit('host-unreachable');
    }
  }
}
