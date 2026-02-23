/**
 * Reusable mock plugin client for E2E tests. Connects to a bridge host
 * on the /plugin WebSocket path, performs v2 register handshake, and
 * supports receiving and responding to action requests from the host.
 */

import { randomUUID } from 'crypto';
import { WebSocket } from 'ws';
import type { Capability, StudioState } from '../../server/web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface MockPluginClientOptions {
  port: number;
  instanceId?: string;
  context?: 'edit' | 'client' | 'server';
  placeName?: string;
  capabilities?: Capability[];
  protocolVersion?: number;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

export class MockPluginClient {
  private _ws: WebSocket | undefined;
  private _options: Required<MockPluginClientOptions>;
  private _sessionId: string;
  private _isConnected = false;
  private _welcomePayload: Record<string, unknown> | undefined;
  private _messageHandlers = new Map<string, Array<(msg: Record<string, unknown>) => void>>();
  private _allMessageHandlers: Array<(msg: Record<string, unknown>) => void> = [];

  constructor(options: MockPluginClientOptions) {
    this._sessionId = randomUUID();
    this._options = {
      port: options.port,
      instanceId: options.instanceId ?? randomUUID(),
      context: options.context ?? 'edit',
      placeName: options.placeName ?? 'TestPlace',
      capabilities: options.capabilities ?? ['execute', 'queryState'],
      protocolVersion: options.protocolVersion ?? 2,
    };
  }

  /**
   * Connect to the bridge host WebSocket endpoint.
   */
  async connectAsync(): Promise<void> {
    const url = `ws://localhost:${this._options.port}/plugin`;
    this._ws = new WebSocket(url);

    await new Promise<void>((resolve, reject) => {
      this._ws!.on('open', () => {
        this._isConnected = true;
        resolve();
      });
      this._ws!.on('error', reject);
    });

    // Set up message routing
    this._ws.on('message', (raw) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      let msg: Record<string, unknown>;
      try {
        msg = JSON.parse(data) as Record<string, unknown>;
      } catch {
        return;
      }

      const type = msg.type as string;

      // Dispatch to type-specific handlers
      const handlers = this._messageHandlers.get(type);
      if (handlers) {
        for (const handler of [...handlers]) {
          handler(msg);
        }
      }

      // Dispatch to all-message handlers
      for (const handler of [...this._allMessageHandlers]) {
        handler(msg);
      }
    });

    this._ws.on('close', () => {
      this._isConnected = false;
    });

    this._ws.on('error', () => {
      // Errors handled via close
    });
  }

  /**
   * Send a v2 register message to the bridge host.
   */
  async sendRegisterAsync(): Promise<void> {
    if (!this._ws || !this._isConnected) {
      throw new Error('MockPluginClient is not connected');
    }

    const stateMap: Record<string, StudioState> = {
      edit: 'Edit',
      client: 'Client',
      server: 'Server',
    };

    this._ws.send(JSON.stringify({
      type: 'register',
      sessionId: this._sessionId,
      protocolVersion: this._options.protocolVersion,
      payload: {
        pluginVersion: '2.0.0-test',
        instanceId: this._options.instanceId,
        placeName: this._options.placeName,
        state: stateMap[this._options.context] ?? 'Edit',
        capabilities: this._options.capabilities,
      },
    }));
  }

  /**
   * Wait for a welcome message from the host. Returns the welcome payload.
   */
  async waitForWelcomeAsync(timeoutMs = 5_000): Promise<Record<string, unknown>> {
    if (this._welcomePayload) {
      return this._welcomePayload;
    }

    return new Promise<Record<string, unknown>>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`Timed out waiting for welcome after ${timeoutMs}ms`));
      }, timeoutMs);

      this.onMessage('welcome', (msg) => {
        clearTimeout(timer);
        this._welcomePayload = msg.payload as Record<string, unknown>;
        resolve(this._welcomePayload);
      });
    });
  }

  /**
   * Wait for a specific message type from the host. Returns the full message.
   */
  async waitForMessageAsync(type: string, timeoutMs = 5_000): Promise<Record<string, unknown>> {
    return new Promise<Record<string, unknown>>((resolve, reject) => {
      const timer = setTimeout(() => {
        cleanup();
        reject(new Error(`Timed out waiting for '${type}' message after ${timeoutMs}ms`));
      }, timeoutMs);

      const handler = (msg: Record<string, unknown>) => {
        clearTimeout(timer);
        cleanup();
        resolve(msg);
      };

      const cleanup = () => {
        const handlers = this._messageHandlers.get(type);
        if (handlers) {
          const idx = handlers.indexOf(handler);
          if (idx >= 0) handlers.splice(idx, 1);
        }
      };

      this._addHandler(type, handler);
    });
  }

  /**
   * Send a raw JSON message to the host.
   */
  sendMessage(msg: Record<string, unknown>): void {
    if (!this._ws || !this._isConnected) {
      throw new Error('MockPluginClient is not connected');
    }
    this._ws.send(JSON.stringify(msg));
  }

  /**
   * Register a one-time handler for a specific message type.
   */
  onMessage(type: string, handler: (msg: Record<string, unknown>) => void): void {
    this._addHandler(type, handler);
  }

  /**
   * Register a handler called for every incoming message.
   */
  onAnyMessage(handler: (msg: Record<string, unknown>) => void): void {
    this._allMessageHandlers.push(handler);
  }

  /**
   * Auto-respond to action requests from the host. Sets up a handler
   * that replies with the given response when an action of the specified
   * type is received. The requestId is automatically copied from the
   * incoming request.
   */
  autoRespond(
    actionType: string,
    responseFactory: (request: Record<string, unknown>) => Record<string, unknown>,
  ): void {
    this.onAnyMessage((msg) => {
      if (msg.type === actionType) {
        const response = responseFactory(msg);
        // Copy requestId from the incoming request
        if (msg.requestId) {
          response.requestId = msg.requestId;
        }
        if (!response.sessionId) {
          response.sessionId = this._sessionId;
        }
        this.sendMessage(response);
      }
    });
  }

  /**
   * Disconnect from the host.
   */
  async disconnectAsync(): Promise<void> {
    if (this._ws) {
      if (this._ws.readyState === WebSocket.OPEN || this._ws.readyState === WebSocket.CONNECTING) {
        this._ws.close();
        // Wait for close to complete
        await new Promise<void>((resolve) => {
          this._ws!.on('close', resolve);
          // If already closed, resolve immediately
          if (this._ws!.readyState === WebSocket.CLOSED) {
            resolve();
          }
        });
      }
      this._ws = undefined;
    }
    this._isConnected = false;
    this._messageHandlers.clear();
    this._allMessageHandlers = [];
    this._welcomePayload = undefined;
  }

  /** Whether the client is currently connected. */
  get isConnected(): boolean {
    return this._isConnected;
  }

  /** The auto-generated session ID for this mock plugin. */
  get sessionId(): string {
    return this._sessionId;
  }

  /** The instance ID. */
  get instanceId(): string {
    return this._options.instanceId;
  }

  // -----------------------------------------------------------------------
  // Convenience: connect + register + wait for welcome in one call
  // -----------------------------------------------------------------------

  /**
   * Connect, register, and wait for welcome. Returns the welcome payload.
   */
  async connectAndRegisterAsync(): Promise<Record<string, unknown>> {
    await this.connectAsync();
    const welcomePromise = this.waitForWelcomeAsync();
    await this.sendRegisterAsync();
    return welcomePromise;
  }

  // -----------------------------------------------------------------------
  // Private
  // -----------------------------------------------------------------------

  private _addHandler(type: string, handler: (msg: Record<string, unknown>) => void): void {
    let handlers = this._messageHandlers.get(type);
    if (!handlers) {
      handlers = [];
      this._messageHandlers.set(type, handlers);
    }
    handlers.push(handler);
  }
}
