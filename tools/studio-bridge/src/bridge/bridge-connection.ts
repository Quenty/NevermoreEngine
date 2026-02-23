/**
 * Public entry point for connecting to the studio-bridge network. Handles
 * host/client role detection transparently. Consumers never create a
 * BridgeHost, BridgeClient, TransportServer, or any other internal type.
 *
 * Use the static factory `connectAsync()` to create instances.
 */

import { EventEmitter } from 'events';
import { BridgeHost } from './internal/bridge-host.js';
import { BridgeClient } from './internal/bridge-client.js';
import { SessionTracker, type TrackedSession } from './internal/session-tracker.js';
import { detectRoleAsync } from './internal/environment-detection.js';
import { BridgeSession } from './bridge-session.js';
import type {
  SessionInfo,
  SessionContext,
  InstanceInfo,
} from './types.js';
import {
  SessionNotFoundError,
  ContextNotFoundError,
} from './types.js';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface BridgeConnectionOptions {
  /** Port for the bridge host. Default: 38741. */
  port?: number;
  /** Max time to wait for initial connection setup. Default: 30_000ms. */
  timeoutMs?: number;
  /** Keep the host alive even when idle. Default: false. */
  keepAlive?: boolean;
  /** Skip local port-bind attempt and connect directly as client. */
  remoteHost?: string;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_PORT = 38741;
const DEFAULT_TIMEOUT_MS = 30_000;
const IDLE_EXIT_GRACE_MS = 5_000;

// ---------------------------------------------------------------------------
// Stub transport handle for host-mode sessions
// ---------------------------------------------------------------------------

/**
 * Minimal transport handle used by SessionTracker in host mode.
 * The BridgeHost manages WebSocket connections directly; this stub
 * provides the interface that SessionTracker requires.
 */
class HostStubTransportHandle extends EventEmitter {
  private _connected = true;

  get isConnected(): boolean {
    return this._connected;
  }

  async sendActionAsync<TResponse>(): Promise<TResponse> {
    throw new Error('Host transport handle: not wired to plugin WebSocket');
  }

  sendMessage(): void {
    // no-op stub
  }

  markDisconnected(): void {
    this._connected = false;
    this.emit('disconnected');
  }
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

export class BridgeConnection extends EventEmitter {
  private _role: 'host' | 'client';
  private _isConnected: boolean = false;
  private _keepAlive: boolean;

  // Host mode internals
  private _host: BridgeHost | undefined;
  private _tracker: SessionTracker | undefined;
  private _hostSessions: Map<string, BridgeSession> = new Map();
  private _hostHandles: Map<string, HostStubTransportHandle> = new Map();

  // Client mode internals
  private _client: BridgeClient | undefined;

  // Idle exit
  private _idleTimer: ReturnType<typeof setTimeout> | undefined;

  private constructor(role: 'host' | 'client', keepAlive: boolean) {
    super();
    this._role = role;
    this._keepAlive = keepAlive;
  }

  /**
   * Connect to the studio-bridge network and return a ready-to-use
   * BridgeConnection.
   *
   * - If no host is running: binds the port, becomes the host.
   * - If a host is running: connects as a client.
   * - If remoteHost is specified: connects directly as a client.
   */
  static async connectAsync(options?: BridgeConnectionOptions): Promise<BridgeConnection> {
    const port = options?.port ?? DEFAULT_PORT;
    const keepAlive = options?.keepAlive ?? false;
    const remoteHost = options?.remoteHost;

    const detection = await detectRoleAsync({ port, remoteHost });

    const conn = new BridgeConnection(detection.role, keepAlive);

    if (detection.role === 'host') {
      await conn._initHostAsync(detection.port);
    } else {
      await conn._initClientAsync(detection.port, remoteHost);
    }

    return conn;
  }

  /**
   * Disconnect from the bridge network.
   */
  async disconnectAsync(): Promise<void> {
    if (!this._isConnected) {
      return;
    }

    this._clearIdleTimer();
    this._isConnected = false;

    if (this._role === 'host' && this._host) {
      // Mark all host handles as disconnected
      for (const handle of this._hostHandles.values()) {
        handle.markDisconnected();
      }
      await this._host.stopAsync();
      this._host = undefined;
      this._tracker = undefined;
      this._hostSessions.clear();
      this._hostHandles.clear();
    }

    if (this._role === 'client' && this._client) {
      await this._client.disconnectAsync();
      this._client = undefined;
    }
  }

  /** Whether this process ended up as host or client. */
  get role(): 'host' | 'client' {
    return this._role;
  }

  /** Whether the connection is currently active. */
  get isConnected(): boolean {
    return this._isConnected;
  }

  /** The actual port the bridge is bound to (host) or connected to (client). */
  get port(): number {
    if (this._role === 'host' && this._host) {
      return this._host.port;
    }
    return 0;
  }

  // -----------------------------------------------------------------------
  // Session access
  // -----------------------------------------------------------------------

  /** List all currently connected Studio sessions. */
  listSessions(): SessionInfo[] {
    if (this._role === 'host' && this._tracker) {
      return this._tracker.listSessions();
    }

    if (this._role === 'client' && this._client) {
      return this._client.listSessions();
    }

    return [];
  }

  /**
   * List unique Studio instances. Each instance groups 1-3 context sessions
   * that share the same instanceId.
   */
  listInstances(): InstanceInfo[] {
    if (this._role === 'host' && this._tracker) {
      return this._tracker.listInstances();
    }

    if (this._role === 'client' && this._client) {
      return this._client.listInstances();
    }

    return [];
  }

  /** Get a session handle by ID. Returns undefined if not connected. */
  getSession(sessionId: string): BridgeSession | undefined {
    if (this._role === 'host') {
      return this._hostSessions.get(sessionId);
    }

    if (this._role === 'client' && this._client) {
      return this._client.getSession(sessionId);
    }

    return undefined;
  }

  // -----------------------------------------------------------------------
  // Session resolution
  // -----------------------------------------------------------------------

  /**
   * Resolve a session for command execution. Instance-aware: groups sessions
   * by instanceId and auto-selects context within an instance.
   *
   * Algorithm (from tech-spec 07, section 6.7):
   * 1. If sessionId -> return that specific session.
   * 2. If instanceId -> select that instance, then apply context selection.
   * 3. Collect unique instances.
   * 4. 0 instances -> throw SessionNotFoundError.
   * 5. 1 instance:
   *    a. If context -> return matching context. Throw ContextNotFoundError if not found.
   *    b. If 1 context -> return it.
   *    c. If N contexts (Play mode) -> return Edit context by default.
   * 6. N instances -> throw SessionNotFoundError with instance list.
   */
  async resolveSession(
    sessionId?: string,
    context?: SessionContext,
    instanceId?: string,
  ): Promise<BridgeSession> {
    // Step 1: Direct session lookup
    if (sessionId) {
      const session = this.getSession(sessionId);
      if (session) {
        return session;
      }
      throw new SessionNotFoundError(
        `Session '${sessionId}' not found`,
        sessionId,
      );
    }

    // Step 2: Instance-specific lookup
    if (instanceId) {
      return this._resolveByInstance(instanceId, context);
    }

    // Step 3: Collect unique instances
    const instances = this.listInstances();

    // Step 4: No instances
    if (instances.length === 0) {
      throw new SessionNotFoundError('No sessions connected');
    }

    // Step 5: Single instance
    if (instances.length === 1) {
      return this._resolveByInstance(instances[0].instanceId, context);
    }

    // Step 6: Multiple instances
    const instanceList = instances
      .map((inst) => `  - ${inst.instanceId}: ${inst.placeName} (${inst.contexts.join(', ')})`)
      .join('\n');

    throw new SessionNotFoundError(
      `Multiple Studio instances connected. Use --session <id> or --instance <id> to select one.\n${instanceList}`,
    );
  }

  // -----------------------------------------------------------------------
  // Session waiting
  // -----------------------------------------------------------------------

  /**
   * Wait for at least one session to connect.
   * Resolves with the first session. Rejects after timeout.
   */
  async waitForSession(timeout?: number): Promise<BridgeSession> {
    // Check if sessions already exist
    const sessions = this.listSessions();
    if (sessions.length > 0) {
      const session = this.getSession(sessions[0].sessionId);
      if (session) {
        return session;
      }
    }

    const timeoutMs = timeout ?? DEFAULT_TIMEOUT_MS;

    return new Promise<BridgeSession>((resolve, reject) => {
      let timer: ReturnType<typeof setTimeout> | undefined;

      const onSession = (session: BridgeSession) => {
        if (timer) {
          clearTimeout(timer);
        }
        resolve(session);
      };

      timer = setTimeout(() => {
        this.off('session-connected', onSession);
        reject(new Error(
          `Timed out waiting for a session to connect (${timeoutMs}ms)`,
        ));
      }, timeoutMs);

      this.once('session-connected', onSession);
    });
  }

  // -----------------------------------------------------------------------
  // Private: Host initialization
  // -----------------------------------------------------------------------

  private async _initHostAsync(port: number): Promise<void> {
    this._host = new BridgeHost();
    this._tracker = new SessionTracker();

    // Wire session tracker events to BridgeConnection events
    this._tracker.on('session-added', (tracked: TrackedSession) => {
      const session = new BridgeSession(tracked.info, tracked.handle);
      this._hostSessions.set(tracked.info.sessionId, session);
      this.emit('session-connected', session);
      this._resetIdleTimer();
    });

    this._tracker.on('session-removed', (sessionId: string) => {
      this._hostSessions.delete(sessionId);
      this._hostHandles.delete(sessionId);
      this.emit('session-disconnected', sessionId);
      this._resetIdleTimer();
    });

    this._tracker.on('instance-added', (instance: InstanceInfo) => {
      this.emit('instance-connected', instance);
    });

    this._tracker.on('instance-removed', (instanceId: string) => {
      this.emit('instance-disconnected', instanceId);
    });

    // Wire BridgeHost plugin events to the session tracker
    this._host.on('plugin-connected', (info) => {
      // Derive context from Studio state
      const state = info.state ?? 'Edit';
      const context = BridgeConnection._deriveContext(state);

      // Build SessionInfo from PluginSessionInfo
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

      const handle = new HostStubTransportHandle();
      this._hostHandles.set(info.sessionId, handle);
      this._tracker!.addSession(info.sessionId, sessionInfo, handle);
    });

    this._host.on('plugin-disconnected', (sessionId: string) => {
      const handle = this._hostHandles.get(sessionId);
      if (handle) {
        handle.markDisconnected();
      }
      this._tracker!.removeSession(sessionId);
    });

    await this._host.startAsync({ port });
    this._isConnected = true;
    this._resetIdleTimer();
  }

  // -----------------------------------------------------------------------
  // Private: Client initialization
  // -----------------------------------------------------------------------

  private async _initClientAsync(port: number, remoteHost?: string): Promise<void> {
    this._client = new BridgeClient();

    // Wire client events to BridgeConnection events
    this._client.on('session-connected', (session: BridgeSession) => {
      this.emit('session-connected', session);
    });

    this._client.on('session-disconnected', (sessionId: string) => {
      this.emit('session-disconnected', sessionId);
    });

    this._client.on('disconnected', () => {
      this._isConnected = false;
    });

    const host = remoteHost ? remoteHost.split(':')[0] : undefined;
    await this._client.connectAsync(port, host);
    this._isConnected = true;
  }

  // -----------------------------------------------------------------------
  // Private: Context derivation
  // -----------------------------------------------------------------------

  /**
   * Derive the session context from the Studio state reported by the plugin.
   * - 'Server' state -> 'server' context
   * - 'Client' state -> 'client' context
   * - Everything else -> 'edit' context
   */
  private static _deriveContext(state: string): SessionContext {
    if (state === 'Server') return 'server';
    if (state === 'Client') return 'client';
    return 'edit';
  }

  // -----------------------------------------------------------------------
  // Private: Instance resolution helper
  // -----------------------------------------------------------------------

  private _resolveByInstance(
    instanceId: string,
    context?: SessionContext,
  ): BridgeSession {
    const sessions = this.listSessions().filter(
      (s) => s.instanceId === instanceId,
    );

    if (sessions.length === 0) {
      throw new SessionNotFoundError(
        `Instance '${instanceId}' not found`,
      );
    }

    const contexts = sessions.map((s) => s.context);

    // 5a: Context specified
    if (context) {
      const match = sessions.find((s) => s.context === context);
      if (match) {
        const session = this.getSession(match.sessionId);
        if (session) {
          return session;
        }
      }
      throw new ContextNotFoundError(context, instanceId, contexts);
    }

    // 5b: Single context
    if (sessions.length === 1) {
      const session = this.getSession(sessions[0].sessionId);
      if (session) {
        return session;
      }
    }

    // 5c: Multiple contexts -> return Edit
    const editSession = sessions.find((s) => s.context === 'edit');
    if (editSession) {
      const session = this.getSession(editSession.sessionId);
      if (session) {
        return session;
      }
    }

    // Fallback: return first session
    const fallback = this.getSession(sessions[0].sessionId);
    if (fallback) {
      return fallback;
    }

    throw new SessionNotFoundError(
      `No session found for instance '${instanceId}'`,
    );
  }

  // -----------------------------------------------------------------------
  // Private: Idle exit management
  // -----------------------------------------------------------------------

  private _resetIdleTimer(): void {
    if (this._keepAlive) {
      return;
    }

    this._clearIdleTimer();

    // Only start idle timer if we're the host and have no sessions
    if (this._role === 'host' && this._tracker) {
      if (this._tracker.sessionCount === 0) {
        this._idleTimer = setTimeout(() => {
          this.disconnectAsync().catch(() => {
            // Ignore disconnect errors during idle shutdown
          });
        }, IDLE_EXIT_GRACE_MS);
      }
    }
  }

  private _clearIdleTimer(): void {
    if (this._idleTimer !== undefined) {
      clearTimeout(this._idleTimer);
      this._idleTimer = undefined;
    }
  }
}
