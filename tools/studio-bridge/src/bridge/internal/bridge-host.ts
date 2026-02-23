/**
 * Bridge host that manages plugin connections. Creates a TransportServer
 * and registers handlers for the /plugin and /health paths. Tracks
 * connected plugins by sessionId and emits events on connect/disconnect.
 */

import { EventEmitter } from 'events';
import type { WebSocket, RawData } from 'ws';
import type { IncomingMessage } from 'http';
import { TransportServer, type TransportServerOptions } from './transport-server.js';
import { createHealthHandler } from './health-endpoint.js';
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
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

const PROTOCOL_VERSION = 2;

export class BridgeHost extends EventEmitter {
  private _transport: TransportServer;
  private _plugins: Map<string, WebSocket> = new Map();
  private _isRunning = false;
  private _startTime = 0;

  constructor() {
    super();
    this._transport = new TransportServer();
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

    // Register /plugin WebSocket handler
    this._transport.onConnection('/plugin', (ws, request) => {
      this._handlePluginConnection(ws, request);
    });

    // Register /health HTTP handler
    this._transport.onHttpRequest('/health', createHealthHandler(() => ({
      port: this._transport.port,
      protocolVersion: PROTOCOL_VERSION,
      sessions: this._plugins.size,
      startTime: this._startTime,
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
    await this._transport.stopAsync();
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
