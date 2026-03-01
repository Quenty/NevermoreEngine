/**
 * Low-level WebSocket client with automatic reconnection and exponential
 * backoff. Handles connection, message send/receive, and reconnection
 * on disconnect. No business logic -- it is a dumb pipe.
 */

import { EventEmitter } from 'events';
import { WebSocket } from 'ws';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface TransportClientOptions {
  /** Maximum number of reconnection attempts. Default: 10. */
  maxReconnectAttempts?: number;
  /** Initial backoff delay in ms. Default: 1000. */
  initialBackoffMs?: number;
  /** Maximum backoff delay in ms. Default: 30000. */
  maxBackoffMs?: number;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

const DEFAULT_MAX_RECONNECT_ATTEMPTS = 10;
const DEFAULT_INITIAL_BACKOFF_MS = 1_000;
const DEFAULT_MAX_BACKOFF_MS = 30_000;

export class TransportClient extends EventEmitter {
  private _ws: WebSocket | undefined;
  private _url: string = '';
  private _isConnected = false;
  private _reconnectAttempt = 0;
  private _reconnectTimer: ReturnType<typeof setTimeout> | undefined;
  private _options: Required<TransportClientOptions> = {
    maxReconnectAttempts: DEFAULT_MAX_RECONNECT_ATTEMPTS,
    initialBackoffMs: DEFAULT_INITIAL_BACKOFF_MS,
    maxBackoffMs: DEFAULT_MAX_BACKOFF_MS,
  };
  private _intentionalClose = false;

  /**
   * Connect to the given WebSocket URL. Resolves when the connection is
   * established. Rejects if the initial connection fails.
   */
  async connectAsync(url: string, options?: TransportClientOptions): Promise<void> {
    this._url = url;
    this._intentionalClose = false;

    if (options) {
      this._options = {
        maxReconnectAttempts: options.maxReconnectAttempts ?? DEFAULT_MAX_RECONNECT_ATTEMPTS,
        initialBackoffMs: options.initialBackoffMs ?? DEFAULT_INITIAL_BACKOFF_MS,
        maxBackoffMs: options.maxBackoffMs ?? DEFAULT_MAX_BACKOFF_MS,
      };
    }

    await this._connectInternalAsync();
  }

  /**
   * Disconnect from the server. Does not attempt reconnection.
   */
  disconnect(): void {
    this._intentionalClose = true;
    this._clearReconnectTimer();

    if (this._ws) {
      this._ws.removeAllListeners();
      if (
        this._ws.readyState === WebSocket.OPEN ||
        this._ws.readyState === WebSocket.CONNECTING
      ) {
        this._ws.close();
      }
      this._ws = undefined;
    }

    if (this._isConnected) {
      this._isConnected = false;
      this.emit('disconnected');
    }
  }

  /**
   * Send a string message over the WebSocket.
   */
  send(data: string): void {
    if (!this._ws || this._ws.readyState !== WebSocket.OPEN) {
      throw new Error('TransportClient is not connected');
    }
    this._ws.send(data);
  }

  /** Whether the client is currently connected. */
  get isConnected(): boolean {
    return this._isConnected;
  }

  // -------------------------------------------------------------------------
  // Private
  // -------------------------------------------------------------------------

  private _connectInternalAsync(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const ws = new WebSocket(this._url);
      this._ws = ws;

      const onOpen = () => {
        cleanup();
        this._isConnected = true;
        this._reconnectAttempt = 0;
        this._setupMessageHandler(ws);
        this.emit('connected');
        resolve();
      };

      const onError = (err: Error) => {
        cleanup();
        reject(err);
      };

      const onClose = () => {
        cleanup();
        reject(new Error(`WebSocket closed before connection to ${this._url}`));
      };

      const cleanup = () => {
        ws.off('open', onOpen);
        ws.off('error', onError);
        ws.off('close', onClose);
      };

      ws.on('open', onOpen);
      ws.on('error', onError);
      ws.on('close', onClose);
    });
  }

  private _setupMessageHandler(ws: WebSocket): void {
    ws.on('message', (raw) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      this.emit('message', data);
    });

    ws.on('close', () => {
      this._isConnected = false;
      this.emit('disconnected');

      if (!this._intentionalClose) {
        this._scheduleReconnect();
      }
    });

    ws.on('error', (err) => {
      this.emit('error', err);
    });
  }

  private _scheduleReconnect(): void {
    if (this._reconnectAttempt >= this._options.maxReconnectAttempts) {
      this.emit('error', new Error(
        `Failed to reconnect after ${this._options.maxReconnectAttempts} attempts`,
      ));
      return;
    }

    const backoff = Math.min(
      this._options.initialBackoffMs * Math.pow(2, this._reconnectAttempt),
      this._options.maxBackoffMs,
    );

    this._reconnectAttempt++;

    this._reconnectTimer = setTimeout(async () => {
      try {
        await this._connectInternalAsync();
      } catch {
        // _connectInternalAsync rejected -- the close handler in
        // _setupMessageHandler will fire and schedule the next retry
        // IF the connection actually opened and then closed. But if
        // the connection never opened, we need to schedule manually.
        if (!this._isConnected && !this._intentionalClose) {
          this._scheduleReconnect();
        }
      }
    }, backoff);
  }

  private _clearReconnectTimer(): void {
    if (this._reconnectTimer !== undefined) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = undefined;
    }
  }
}
