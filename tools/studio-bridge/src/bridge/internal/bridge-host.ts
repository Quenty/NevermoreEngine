/**
 * Bridge host that manages plugin connections. Creates a TransportServer
 * and registers handlers for the /plugin and /health paths. Tracks
 * connected plugins by sessionId and emits events on connect/disconnect.
 */

import { EventEmitter } from 'events';
import { randomUUID } from 'crypto';
import type { WebSocket, RawData } from 'ws';
import type { IncomingMessage } from 'http';
import { TransportServer } from './transport-server.js';
import { createHealthHandler } from './health-endpoint.js';
import {
  decodeHostMessage,
  encodeHostMessage,
  type HostProtocolMessage,
  type HostTransferNotice,
} from './host-protocol.js';
import {
  decodePluginMessage,
  encodeMessage,
  type Capability,
  type ServerMessage,
} from '../../server/web-socket-protocol.js';
import { PendingRequestMap } from '../../server/pending-request-map.js';
import { OutputHelper } from '@quenty/cli-output-helpers';

export interface BridgeHostOptions {
  /** Port to bind on. Default: 38741. Use 0 for ephemeral (test-friendly). */
  port?: number;
  /** Host to bind on. Default: 'localhost'. */
  host?: string;
}

export interface PluginSessionInfo {
  sessionId: string;
  pluginVersion?: string;
  capabilities: Capability[];
  /** Instance ID from register. */
  instanceId?: string;
  /** Place name from register. */
  placeName?: string;
  /** Studio state from register. */
  state?: string;
  /** Place file from register. */
  placeFile?: string;
}

const SHUTDOWN_TIMEOUT_MS = 2_000;
const SHUTDOWN_DRAIN_MS = 250;

/**
 * Per-plugin connection state. The `pendingRequests` map correlates outgoing
 * requests to incoming responses by `requestId`. A single message dispatcher
 * is installed per connection and routes through this map; this avoids the
 * older per-call `ws.on('message', ...)` pattern, which both leaked listeners
 * and could match the wrong response when ≥2 requests were in flight.
 */
interface PluginConnectionState {
  ws: WebSocket;
  pendingRequests: PendingRequestMap<unknown>;
}

export class BridgeHost extends EventEmitter {
  private _transport: TransportServer;
  private _plugins: Map<string, PluginConnectionState> = new Map();
  private _clients: Set<WebSocket> = new Set();
  private _isRunning = false;
  private _shuttingDown = false;
  private _startTime = 0;
  private _hostStartTime = 0;
  private _lastFailoverAt: string | null = null;

  constructor() {
    super();
    this._transport = new TransportServer();
  }

  /** Time (ms) since this process became the host. */
  get hostUptime(): number {
    if (this._hostStartTime === 0) {
      return 0;
    }
    return Date.now() - this._hostStartTime;
  }

  /** ISO timestamp of the last failover event, or null if none. */
  get lastFailoverAt(): string | null {
    return this._lastFailoverAt;
  }

  markFailover(): void {
    this._hostStartTime = Date.now();
    this._lastFailoverAt = new Date().toISOString();
  }

  /** Returns the actual bound port. */
  async startAsync(options?: BridgeHostOptions): Promise<number> {
    if (this._isRunning) {
      throw new Error('BridgeHost is already running');
    }

    this._startTime = Date.now();
    if (this._hostStartTime === 0) {
      this._hostStartTime = this._startTime;
    }

    // Register /plugin WebSocket handler — reject during shutdown
    this._transport.onConnection('/plugin', (ws, request) => {
      if (this._shuttingDown) {
        ws.close(1001, 'host shutting down');
        return;
      }
      this._handlePluginConnection(ws, request);
    });

    // Register /client WebSocket handler for CLI clients
    this._transport.onConnection('/client', (ws) => {
      this._clients.add(ws);

      ws.on('message', (raw: RawData) => {
        const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
        const msg = decodeHostMessage(data);
        if (!msg) {
          return;
        }
        this.emit('client-message', msg, (reply: HostProtocolMessage) => {
          ws.send(encodeHostMessage(reply));
        });
      });

      ws.on('close', () => {
        this._clients.delete(ws);
      });
      ws.on('error', () => {
        // Errors are handled implicitly via close
      });
    });

    // Register /health HTTP handler — returns 503 during shutdown so
    // plugins don't rediscover a host that's about to close
    this._transport.onHttpRequest('/health', (req, res) => {
      if (this._shuttingDown) {
        res.writeHead(503);
        res.end();
        return;
      }
      createHealthHandler(() => ({
        port: this._transport.port,
        sessions: this._plugins.size,
        startTime: this._startTime,
        hostStartTime: this._hostStartTime,
        lastFailoverAt: this._lastFailoverAt,
      }))(req, res);
    });

    const port = await this._transport.startAsync({
      port: options?.port,
      host: options?.host,
    });

    this._isRunning = true;
    return port;
  }

  async stopAsync(): Promise<void> {
    if (!this._isRunning) {
      return;
    }
    this._isRunning = false;
    this._cancelAllPending('host stopped');
    this._plugins.clear();
    this._clients.clear();
    await this._transport.stopAsync();
  }

  /**
   * Graceful shutdown: broadcast HostTransferNotice to all connected clients,
   * wait briefly for them to process it, then close all connections and
   * release the port. Idempotent — calling multiple times is safe.
   *
   * Wrapped in a timeout: if the graceful sequence exceeds 2 seconds, the
   * transport is force-closed to ensure the port is freed.
   */
  async shutdownAsync(): Promise<void> {
    if (this._shuttingDown) {
      return;
    }
    this._shuttingDown = true;
    OutputHelper.verbose(
      `[host] shutdownAsync called (plugins: ${this._plugins.size}, clients: ${this._clients.size})`
    );
    OutputHelper.verbose(
      `[host] shutdown stack: ${new Error().stack
        ?.split('\n')
        .slice(1, 5)
        .map((s) => s.trim())
        .join(' <- ')}`
    );

    const gracefulShutdown = async () => {
      // Step 1: Broadcast HostTransferNotice to all CLI clients
      const notice: HostTransferNotice = { type: 'host-transfer' };
      const encoded = encodeHostMessage(notice);
      for (const ws of this._clients) {
        try {
          ws.send(encoded);
        } catch {
          // Client may already be disconnected
        }
      }

      // Step 1.5: Send shutdown message to all plugins so they disconnect
      // cleanly instead of seeing a WebSocket error
      for (const [sessionId, state] of this._plugins) {
        try {
          state.ws.send(
            encodeMessage({
              type: 'shutdown',
              sessionId,
              payload: {} as Record<string, never>,
            })
          );
        } catch {
          // Plugin may already be disconnected
        }
      }

      // Step 2: Wait briefly for plugins/clients to process
      await new Promise<void>((resolve) =>
        setTimeout(resolve, SHUTDOWN_DRAIN_MS)
      );

      // Step 3: Send close frames to all plugins and clients
      for (const state of this._plugins.values()) {
        try {
          state.ws.close(1001, 'host shutting down');
        } catch {
          // Ignore
        }
      }
      for (const ws of this._clients) {
        try {
          ws.close(1001, 'host shutting down');
        } catch {
          // Ignore
        }
      }

      // Step 4: Stop the transport
      this._isRunning = false;
      this._cancelAllPending('host shutting down');
      this._plugins.clear();
      this._clients.clear();
      await this._transport.stopAsync();
    };

    // Wrap in timeout — force-close if graceful exceeds limit
    const timeoutPromise = new Promise<'timeout'>((resolve) =>
      setTimeout(() => resolve('timeout'), SHUTDOWN_TIMEOUT_MS)
    );

    const result = await Promise.race([
      gracefulShutdown().then(() => 'done' as const),
      timeoutPromise,
    ]);

    if (result === 'timeout') {
      this._isRunning = false;
      this._cancelAllPending('host force-closed');
      this._plugins.clear();
      this._clients.clear();
      await this._transport.forceCloseAsync();
    }
  }

  /** The actual port the server is bound to. */
  get port(): number {
    return this._transport.port;
  }

  /** Whether the host is currently running. */
  get isRunning(): boolean {
    return this._isRunning;
  }

  /** Number of connected plugin sessions. */
  get pluginCount(): number {
    return this._plugins.size;
  }

  broadcastToClients(msg: HostProtocolMessage): void {
    const encoded = encodeHostMessage(msg);
    for (const ws of this._clients) {
      try {
        ws.send(encoded);
      } catch {
        // Client may already be disconnected
      }
    }
  }

  async sendToPluginAsync<TResponse>(
    sessionId: string,
    message: ServerMessage,
    timeoutMs: number
  ): Promise<TResponse> {
    const state = this._plugins.get(sessionId);
    if (!state) {
      throw new Error(`Plugin session '${sessionId}' not connected`);
    }

    // Every request must carry a requestId so the response can be correlated.
    // All real callers (BridgeSession, BridgeClient) generate one; the fallback
    // here is purely defensive.
    const messageWithId = ensureRequestId(message);
    const requestId = (messageWithId as { requestId: string }).requestId;
    const msgType = messageWithId.type;

    OutputHelper.verbose(
      `[host] → plugin ${sessionId}: ${msgType} (requestId=${requestId.slice(
        0,
        8
      )}, timeout ${timeoutMs}ms)`
    );

    const responsePromise = state.pendingRequests.addRequestAsync(
      requestId,
      timeoutMs
    ) as Promise<TResponse>;

    try {
      state.ws.send(encodeMessage(messageWithId));
    } catch (err) {
      state.pendingRequests.rejectRequest(
        requestId,
        err instanceof Error ? err : new Error(String(err))
      );
      throw err;
    }

    return responsePromise;
  }

  /**
   * Send a fire-and-forget message to a specific plugin.
   */
  sendToPlugin(sessionId: string, message: ServerMessage): void {
    const state = this._plugins.get(sessionId);
    if (!state) {
      return;
    }
    try {
      state.ws.send(encodeMessage(message));
    } catch {
      // Plugin may already be disconnected
    }
  }

  private _handlePluginConnection(
    ws: WebSocket,
    _request: IncomingMessage
  ): void {
    const onMessage = (raw: RawData) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = decodePluginMessage(data);
      if (!msg || msg.type !== 'register') {
        return;
      }

      const sessionId = msg.sessionId;
      const { pluginVersion, capabilities } = msg.payload;

      ws.off('message', onMessage);
      this._registerPlugin(ws, {
        sessionId,
        pluginVersion,
        capabilities,
        instanceId: msg.payload.instanceId,
        placeName: msg.payload.placeName,
        state: msg.payload.state,
        placeFile: msg.payload.placeFile,
      });
    };

    ws.on('message', onMessage);

    ws.on('error', () => {
      // Errors are handled implicitly via close
    });
  }

  private _registerPlugin(ws: WebSocket, info: PluginSessionInfo): void {
    // If a plugin with this sessionId is already connected, close the old
    // connection first so the Map stays consistent. This can happen when a
    // plugin reconnects faster than the host detects the old socket's close.
    const existing = this._plugins.get(info.sessionId);
    if (existing && existing.ws !== ws) {
      try {
        existing.ws.close(1001, 'replaced by new connection');
      } catch {
        // Old socket may already be dead
      }
      existing.pendingRequests.cancelAll(
        'plugin connection replaced by new session'
      );
      // Remove immediately so the old close handler doesn't delete the new entry
      this._plugins.delete(info.sessionId);
    }

    const state: PluginConnectionState = {
      ws,
      pendingRequests: new PendingRequestMap<unknown>(),
    };
    this._plugins.set(info.sessionId, state);

    // Install the persistent dispatcher on this connection. All plugin
    // responses arrive through this listener; matched by requestId via the
    // pending-request map.
    ws.on('message', (raw: RawData) =>
      this._dispatchPluginMessage(info.sessionId, state, raw)
    );

    OutputHelper.verbose(
      `[host] Plugin connected: ${
        info.sessionId
      } (caps: ${info.capabilities.join(', ')})`
    );
    this.emit('plugin-connected', info);

    ws.on('close', () => {
      // Only remove if this socket is still the registered one — a newer
      // connection with the same sessionId may have already replaced us.
      const current = this._plugins.get(info.sessionId);
      if (current && current.ws === ws) {
        current.pendingRequests.cancelAll('plugin disconnected');
        this._plugins.delete(info.sessionId);
        OutputHelper.verbose(`[host] Plugin disconnected: ${info.sessionId}`);
        this.emit('plugin-disconnected', info.sessionId);
      }
    });
  }

  /**
   * Persistent per-connection message dispatcher. Routes responses to the
   * pending-request map by `requestId`. Heartbeats and unsolicited messages
   * are logged but otherwise ignored — there are no host-side consumers of
   * push messages today.
   */
  private _dispatchPluginMessage(
    sessionId: string,
    state: PluginConnectionState,
    raw: RawData
  ): void {
    const data = typeof raw === 'string' ? raw : raw.toString('utf-8');

    // Parse the raw JSON directly — decodePluginMessage's strict schema may
    // reject valid responses we still want to surface to callers.
    let parsed: { type?: unknown; requestId?: unknown; payload?: unknown };
    try {
      parsed = JSON.parse(data);
    } catch {
      return;
    }

    if (parsed.type === 'heartbeat') {
      return;
    }

    const requestId =
      typeof parsed.requestId === 'string' && parsed.requestId !== ''
        ? parsed.requestId
        : undefined;

    if (requestId !== undefined) {
      if (state.pendingRequests.hasPendingRequest(requestId)) {
        OutputHelper.verbose(
          `[host] ← plugin ${sessionId}: ${String(
            parsed.type
          )} (matched requestId=${requestId.slice(0, 8)})`
        );
        state.pendingRequests.resolveRequest(requestId, parsed);
        return;
      }
      OutputHelper.verbose(
        `[host] ← plugin ${sessionId}: dropped ${String(
          parsed.type
        )} for unknown requestId=${requestId.slice(0, 8)}`
      );
      return;
    }

    // No requestId: nothing to correlate against. Errors without a requestId
    // mean the plugin couldn't even parse the inbound request, so there's no
    // pending entry to fail. Surface as a log so failures aren't silent.
    if (parsed.type === 'error') {
      const payload = parsed.payload as
        | { code?: string; message?: string }
        | undefined;
      OutputHelper.warn(
        `[host] plugin ${sessionId} sent error without requestId (${
          payload?.code ?? 'unknown'
        }): ${payload?.message ?? ''}`
      );
      return;
    }

    OutputHelper.verbose(
      `[host] ← plugin ${sessionId}: dropped unsolicited ${String(parsed.type)}`
    );
  }

  private _cancelAllPending(reason: string): void {
    for (const state of this._plugins.values()) {
      state.pendingRequests.cancelAll(reason);
    }
  }
}

/**
 * Ensure the outgoing message carries a `requestId`. All real callers
 * (BridgeSession, BridgeClient) supply one; this is a defensive fallback
 * so the strict-correlation path always has a key to match against.
 */
function ensureRequestId(message: ServerMessage): ServerMessage {
  const existing = (message as { requestId?: string }).requestId;
  if (typeof existing === 'string' && existing !== '') {
    return message;
  }
  return { ...message, requestId: randomUUID() } as ServerMessage;
}
