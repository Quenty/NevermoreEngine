/**
 * Bridge host that manages plugin connections. Creates a TransportServer
 * and registers handlers for the /plugin and /health paths. Tracks
 * connected plugins by sessionId and emits events on connect/disconnect.
 */

import { EventEmitter } from 'events';
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
} from '../../server/web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

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
  protocolVersion: number;
  /** Instance ID from v2 register. Only present for v2 handshakes. */
  instanceId?: string;
  /** Place name from v2 register. */
  placeName?: string;
  /** Studio state from v2 register. */
  state?: string;
  /** Place file from v2 register. */
  placeFile?: string;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

const PROTOCOL_VERSION = 2;
const SHUTDOWN_TIMEOUT_MS = 2_000;
const SHUTDOWN_DRAIN_MS = 100;

export class BridgeHost extends EventEmitter {
  private _transport: TransportServer;
  private _plugins: Map<string, WebSocket> = new Map();
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

  /**
   * Mark this host as having been promoted via failover. Sets the
   * hostStartTime to now and records the failover timestamp.
   */
  markFailover(): void {
    this._hostStartTime = Date.now();
    this._lastFailoverAt = new Date().toISOString();
  }

  /**
   * Start the bridge host. Binds to the specified port and begins
   * accepting plugin connections on /plugin and health checks on /health.
   * Returns the actual bound port.
   */
  async startAsync(options?: BridgeHostOptions): Promise<number> {
    if (this._isRunning) {
      throw new Error('BridgeHost is already running');
    }

    this._startTime = Date.now();
    if (this._hostStartTime === 0) {
      this._hostStartTime = this._startTime;
    }

    // Register /plugin WebSocket handler
    this._transport.onConnection('/plugin', (ws, request) => {
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

    // Register /health HTTP handler
    this._transport.onHttpRequest('/health', createHealthHandler(() => ({
      port: this._transport.port,
      protocolVersion: PROTOCOL_VERSION,
      sessions: this._plugins.size,
      startTime: this._startTime,
      hostStartTime: this._hostStartTime,
      lastFailoverAt: this._lastFailoverAt,
    })));

    const port = await this._transport.startAsync({
      port: options?.port,
      host: options?.host,
    });

    this._isRunning = true;
    return port;
  }

  /**
   * Stop the host and close all connections.
   */
  async stopAsync(): Promise<void> {
    if (!this._isRunning) {
      return;
    }
    this._isRunning = false;
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

      // Step 2: Wait briefly for clients to process the notice
      await new Promise<void>((resolve) => setTimeout(resolve, SHUTDOWN_DRAIN_MS));

      // Step 3: Send close frames to all plugins and clients
      for (const ws of this._plugins.values()) {
        try {
          ws.close(1001, 'host shutting down');
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
      this._plugins.clear();
      this._clients.clear();
      await this._transport.stopAsync();
    };

    // Wrap in timeout — force-close if graceful exceeds limit
    const timeoutPromise = new Promise<'timeout'>((resolve) =>
      setTimeout(() => resolve('timeout'), SHUTDOWN_TIMEOUT_MS),
    );

    const result = await Promise.race([
      gracefulShutdown().then(() => 'done' as const),
      timeoutPromise,
    ]);

    if (result === 'timeout') {
      this._isRunning = false;
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

  /**
   * Send a host protocol message to all connected CLI clients.
   */
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

  // -------------------------------------------------------------------------
  // Private
  // -------------------------------------------------------------------------

  private _handlePluginConnection(ws: WebSocket, _request: IncomingMessage): void {
    // Wait for the first message (handshake: hello or register)
    const onMessage = (raw: RawData) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = decodePluginMessage(data);
      if (!msg) {
        return;
      }

      if (msg.type === 'hello') {
        const sessionId = msg.payload.sessionId;
        const capabilities = msg.payload.capabilities ?? ['execute' as Capability];
        const pluginVersion = msg.payload.pluginVersion;

        // Send welcome
        ws.send(
          encodeMessage({
            type: 'welcome',
            sessionId,
            payload: { sessionId },
          }),
        );

        ws.off('message', onMessage);
        this._registerPlugin(ws, {
          sessionId,
          pluginVersion,
          capabilities,
          protocolVersion: 1,
        });
      } else if (msg.type === 'register') {
        const sessionId = msg.sessionId;
        const { pluginVersion, capabilities } = msg.payload;
        const protocolVersion = Math.min(msg.protocolVersion, PROTOCOL_VERSION);

        // Send v2 welcome with protocolVersion and capabilities
        const welcomePayload: Record<string, unknown> = { sessionId };
        welcomePayload.protocolVersion = protocolVersion;
        welcomePayload.capabilities = capabilities;

        ws.send(JSON.stringify({
          type: 'welcome',
          sessionId,
          payload: welcomePayload,
        }));

        ws.off('message', onMessage);
        this._registerPlugin(ws, {
          sessionId,
          pluginVersion,
          capabilities,
          protocolVersion,
          instanceId: msg.payload.instanceId,
          placeName: msg.payload.placeName,
          state: msg.payload.state,
          placeFile: msg.payload.placeFile,
        });
      }
    };

    ws.on('message', onMessage);

    ws.on('error', () => {
      // Errors are handled implicitly via close
    });
  }

  private _registerPlugin(ws: WebSocket, info: PluginSessionInfo): void {
    this._plugins.set(info.sessionId, ws);
    this.emit('plugin-connected', info);

    ws.on('close', () => {
      this._plugins.delete(info.sessionId);
      this.emit('plugin-disconnected', info.sessionId);
    });
  }
}
