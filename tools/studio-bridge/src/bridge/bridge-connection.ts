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
import {
  SessionTracker,
  type TrackedSession,
} from './internal/session-tracker.js';
import {
  detectRoleAsync,
  getDefaultRemoteHost,
} from './internal/environment-detection.js';
import { BridgeSession } from './bridge-session.js';
import { getHostBuildAsync, type HostBuild } from './internal/host-build.js';
import {
  argvDependsOnCwd,
  assessHost,
  describeHostBuild,
  isServeArgv,
  replaceHostAsync,
  staleHostFromInfo,
  tryFindLegacyHostAsync,
  type StaleHostReport,
} from './internal/stale-host.js';
import {
  describeStaleHost,
  type StaleHostOutcome,
} from './internal/stale-host-report.js';
import { tryAutoStartHostAsync } from './internal/auto-host.js';
import {
  HOST_PROTOCOL_VERSION,
  type HostEnvelope,
  type HostInfo,
  type HostProtocolMessage,
  type ListSessionsRequest,
  type ListInstancesRequest,
} from './internal/host-protocol.js';
import type { SessionInfo, SessionContext, InstanceInfo } from './types.js';
import {
  SessionNotFoundError,
  ContextNotFoundError,
  NO_STUDIO_CONNECTED,
  formatSeconds,
} from './types.js';
import { annotateInstanceState } from './internal/instance-state.js';
import type {
  PluginMessage,
  ServerMessage,
} from '../server/web-socket-protocol.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';
import { RequestTimeoutError } from '../server/pending-request-map.js';
import { warnUser } from '../messages/warn-user.js';

export interface BridgeConnectionOptions {
  /** Port for the bridge host. Default: 38741. */
  port?: number;
  /** Max time to wait for the first Studio session to connect. Default: 5_000ms. */
  timeoutMs?: number;
  /** Keep the host alive even when idle. Default: false. */
  keepAlive?: boolean;
  /** Skip local port-bind attempt and connect directly as client (host:port). */
  remoteHost?: string;
  /** Force local mode -- skip devcontainer auto-detection. */
  local?: boolean;
  /**
   * When true and this process becomes the host, wait for active Studios to
   * discover and connect before returning. Use for short-lived commands that
   * need all sessions available immediately. Default: false.
   */
  waitForSessions?: boolean;
  replaceStaleHost?: boolean;
  autoHost?: boolean;
  hostDetails?: Pick<HostInfo, 'autoStarted' | 'idleTimeoutMs' | 'logPath'>;
}

export type { StaleHostReport };

const DEFAULT_PORT = 38741;
const DEFAULT_TIMEOUT_MS = 30_000;
const IDLE_EXIT_GRACE_MS = 5_000;
/** How long shutdown waits on relayed actions; a started playtest's request lasts until it ends. */
const RELAY_DRAIN_TIMEOUT_MS = 10_000;
const SESSION_RECONNECT_TIMEOUT_MS = 10_000;
const PLUGIN_DISCOVERY_MS = 2_500;
const LIST_SESSIONS_FIX =
  "Run 'studio-bridge process list' to see the connected sessions.";

function formatSessionList(sessions: SessionInfo[]): string {
  return sessions
    .map((s) => `  - ${s.sessionId}: ${s.placeName} (${s.context})`)
    .join('\n');
}

/**
 * Transport handle that relays messages to a plugin's WebSocket via BridgeHost.
 * Used by SessionTracker in host mode so that BridgeSession.sendActionAsync()
 * works the same way whether we're a host or a client.
 */
class HostTransportHandle extends EventEmitter {
  private _connected = true;
  private _sessionId: string;
  private _host: BridgeHost;

  constructor(sessionId: string, host: BridgeHost) {
    super();
    this._sessionId = sessionId;
    this._host = host;
  }

  get isConnected(): boolean {
    return this._connected;
  }

  async sendActionAsync<TResponse>(
    message: ServerMessage,
    timeoutMs: number
  ): Promise<TResponse> {
    return this._host.sendToPluginAsync<TResponse>(
      this._sessionId,
      message,
      timeoutMs
    );
  }

  sendMessage(message: ServerMessage): void {
    this._host.sendToPlugin(this._sessionId, message);
  }

  markDisconnected(): void {
    this._connected = false;
    this.emit('disconnected');
  }
}

export class BridgeConnection extends EventEmitter {
  private _role: 'host' | 'client';
  private _isRemote = false;
  private _isConnected: boolean = false;
  private _keepAlive: boolean;
  private _hasSettled: boolean = false;
  private _firstSessionTimeoutMs: number | undefined;
  private _pendingRelays = new Set<Promise<void>>();
  private _staleHost: StaleHostReport | undefined;
  private _hostBuild: HostBuild | undefined;
  private _hostDetails: BridgeConnectionOptions['hostDetails'];
  private _hostStartedAt = 0;
  private _clientConnectedAt = 0;

  // Host mode internals
  private _host: BridgeHost | undefined;
  private _tracker: SessionTracker | undefined;
  private _hostSessions: Map<string, BridgeSession> = new Map();
  private _hostHandles: Map<string, HostTransportHandle> = new Map();

  // Client mode internals
  private _client: BridgeClient | undefined;
  private _clientPort = 0;

  // Idle exit
  private _idleTimer: ReturnType<typeof setTimeout> | undefined;

  private constructor(role: 'host' | 'client', keepAlive: boolean) {
    super();
    this._role = role;
    this._keepAlive = keepAlive;
    // keepAlive connections (serve mode) manage their own lifecycle —
    // don't auto-settle in resolveSessionAsync
    this._hasSettled = keepAlive;
  }

  /**
   * Connect to the studio-bridge network and return a ready-to-use
   * BridgeConnection.
   *
   * - If remoteHost is specified: connects directly as a client.
   * - If local is specified: skips devcontainer auto-detection, uses local mode.
   * - If no host is running: binds the port, becomes the host.
   * - If a host is running: connects as a client.
   */
  static async connectAsync(
    options?: BridgeConnectionOptions
  ): Promise<BridgeConnection> {
    const keepAlive = options?.keepAlive ?? false;
    const remoteHost = options?.remoteHost;

    let parsedRemoteHost: string | undefined;
    let port = options?.port ?? DEFAULT_PORT;

    if (remoteHost) {
      if (remoteHost.includes(':')) {
        const parts = remoteHost.split(':');
        parsedRemoteHost = remoteHost;
        port = parseInt(parts[parts.length - 1], 10) || DEFAULT_PORT;
      } else {
        parsedRemoteHost = `${remoteHost}:${port}`;
      }
    }

    // Devcontainer auto-detection: if no explicit remoteHost and not forced local,
    // try connecting to the default remote host with a short timeout before falling
    // back to local mode.
    if (!parsedRemoteHost && !options?.local) {
      const autoRemoteHost = getDefaultRemoteHost();
      if (autoRemoteHost) {
        const AUTO_DETECT_TIMEOUT_MS = 3_000;
        try {
          const autoConn = new BridgeConnection('client', keepAlive);
          const autoHost = autoRemoteHost.split(':')[0];
          const autoPort =
            parseInt(autoRemoteHost.split(':')[1], 10) || DEFAULT_PORT;

          await Promise.race([
            autoConn._initClientAsync(autoPort, autoHost),
            new Promise<never>((_, reject) =>
              setTimeout(
                () => reject(new Error('Auto-detection timed out')),
                AUTO_DETECT_TIMEOUT_MS
              )
            ),
          ]);

          autoConn._isRemote = true;
          await autoConn._checkStaleHostAsync(options ?? {});
          return autoConn;
        } catch (err) {
          warnUser({
            code: 'DEVCONTAINER_HOST_UNREACHABLE',
            message: `In a devcontainer, but no bridge host answered at ${autoRemoteHost}, so this command looks for Studio inside the container instead.`,
            fix: "Run 'studio-bridge serve' on the host machine, or pass --local to skip this check.",
            cause: err,
          });
        }
      }
    }

    const detection = await detectRoleAsync({
      port,
      remoteHost: parsedRemoteHost,
    });

    let role = detection.role;
    if (role === 'host' && options?.autoHost) {
      role = await BridgeConnection._tryAutoStartHostAsync(detection.port);
    }

    const conn = new BridgeConnection(role, keepAlive);
    conn._isRemote = parsedRemoteHost !== undefined;
    conn._firstSessionTimeoutMs = options?.timeoutMs;
    conn._hostDetails = options?.hostDetails;
    OutputHelper.verbose(`[bridge] Role: ${role}, port: ${detection.port}`);

    if (role === 'host') {
      await conn._initHostAsync(detection.port);
    } else {
      try {
        await conn._initClientAsync(detection.port, parsedRemoteHost);
      } catch (err: unknown) {
        if (parsedRemoteHost && err instanceof Error) {
          const code = (err as NodeJS.ErrnoException).code;
          if (code === 'ECONNREFUSED') {
            throw new StudioBridgeError({
              code: 'REMOTE_HOST_UNREACHABLE',
              message: `No bridge host answered at ${parsedRemoteHost}.`,
              fix: "Run 'studio-bridge serve' on that machine, then run the command again.",
              cause: err,
            });
          }
          if (
            err.message.includes('timed out') ||
            err.message.includes('timeout')
          ) {
            throw new StudioBridgeError({
              code: 'REMOTE_HOST_TIMEOUT',
              message: `The bridge host at ${parsedRemoteHost} didn't answer within 5s.`,
              fix: `Check that machine is reachable and 'studio-bridge serve' runs there.`,
              cause: err,
            });
          }
        }
        throw err;
      }
    }

    if (conn._role === 'client' && options?.replaceStaleHost !== false) {
      const replacement = await conn._checkStaleHostAsync(options ?? {});
      if (replacement) {
        return replacement;
      }
    }

    if (options?.waitForSessions) {
      await conn._ensureSettledAsync();
    }

    return conn;
  }

  private static async _tryAutoStartHostAsync(
    port: number
  ): Promise<'host' | 'client'> {
    if (await tryAutoStartHostAsync(port)) {
      return 'client';
    }
    return (await detectRoleAsync({ port })).role;
  }

  async disconnectAsync(
    options: { relayDrainTimeoutMs?: number } = {}
  ): Promise<void> {
    if (!this._isConnected) {
      return;
    }
    OutputHelper.verbose(
      `[bridge] disconnectAsync called (role=${this._role})`
    );
    OutputHelper.verbose(
      `[bridge] disconnect stack: ${new Error().stack
        ?.split('\n')
        .slice(1, 5)
        .map((s) => s.trim())
        .join(' <- ')}`
    );

    this._clearIdleTimer();
    this._isConnected = false;

    if (this._role === 'host' && this._host) {
      // Shutting down drops the plugins, so let actions relayed for clients finish
      if (this._pendingRelays.size > 0) {
        OutputHelper.verbose(
          `[bridge] Waiting for ${this._pendingRelays.size} relayed action(s) before shutting down`
        );
        let drainTimer: ReturnType<typeof setTimeout> | undefined;
        await Promise.race([
          Promise.allSettled([...this._pendingRelays]),
          new Promise<void>((resolve) => {
            drainTimer = setTimeout(
              resolve,
              options.relayDrainTimeoutMs ?? RELAY_DRAIN_TIMEOUT_MS
            );
          }),
        ]);
        clearTimeout(drainTimer);
      }

      for (const handle of this._hostHandles.values()) {
        handle.markDisconnected();
      }
      await this._host.shutdownAsync();
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

  get staleHost(): StaleHostReport | undefined {
    return this._staleHost;
  }

  get hostInfo(): HostInfo | undefined {
    if (this._role === 'host') {
      return this._host ? this._describeHost() : undefined;
    }
    return this._client?.hostInfo;
  }

  get clientCount(): number {
    return this._host?.clientCount ?? 0;
  }

  /** Whether the bridge host, and so Studio, runs on another machine. */
  get isRemote(): boolean {
    return this._isRemote;
  }

  get port(): number {
    if (this._host) {
      return this._host.port;
    }
    return this._clientPort;
  }

  /** List all currently connected Studio sessions. */
  listSessions(): SessionInfo[] {
    if (this._role === 'host' && this._tracker) {
      return annotateInstanceState(this._tracker.listSessions());
    }

    if (this._role === 'client' && this._client) {
      return annotateInstanceState(this._client.listSessions());
    }

    return [];
  }

  /**
   * Sessions matching `--target` and `--context`. A target matches a
   * session id or an instance id exactly, or else as a prefix.
   */
  findSessions(target?: string, context?: SessionContext): SessionInfo[] {
    let sessions = this.listSessions();
    if (target) {
      const exact = sessions.find((s) => s.sessionId === target);
      if (exact && !context) return [exact];

      const instanceIds = exact
        ? [exact.instanceId]
        : this._matchInstanceIds(target);
      sessions = sessions.filter((s) => instanceIds.includes(s.instanceId));
    }
    if (context) {
      sessions = sessions.filter((s) => s.context === context);
    }
    return sessions;
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

  /**
   * Instances whose id, or one of whose session ids, is `target`. Falls
   * back to ids that start with `target` when nothing matches exactly.
   */
  private _matchInstanceIds(target: string): string[] {
    const sessions = this.listSessions();
    const exact = new Set(
      sessions
        .filter((s) => s.instanceId === target || s.sessionId === target)
        .map((s) => s.instanceId)
    );
    if (exact.size > 0) return [...exact];

    return [
      ...new Set(
        sessions
          .filter(
            (s) =>
              s.instanceId.startsWith(target) || s.sessionId.startsWith(target)
          )
          .map((s) => s.instanceId)
      ),
    ];
  }

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
  async resolveSessionAsync(
    sessionId?: string,
    context?: SessionContext,
    instanceId?: string
  ): Promise<BridgeSession> {
    // Fresh host hasn't settled yet — wait for persistent plugins to discover us
    await this._ensureSettledAsync();

    if (sessionId) {
      const session = this.getSession(sessionId);
      if (session && (!context || session.info.context === context)) {
        return session;
      }

      const prefixed = this.listSessions().filter(
        (s) =>
          s.sessionId.startsWith(sessionId) &&
          (!context || s.context === context)
      );
      const onlyPrefixed =
        prefixed.length === 1 ? this.getSession(prefixed[0].sessionId) : null;
      if (onlyPrefixed) {
        return onlyPrefixed;
      }
      const namesInstance = prefixed.some((s) =>
        s.instanceId.startsWith(sessionId)
      );
      if (!session && prefixed.length > 1 && !namesInstance) {
        throw new SessionNotFoundError({
          message: `--target '${sessionId}' matches several sessions.`,
          fix: `Use a longer --target, one of:\n${formatSessionList(prefixed)}`,
          sessionId,
        });
      }

      const instanceIds = session
        ? [session.info.instanceId]
        : this._matchInstanceIds(sessionId);
      if (instanceIds.length === 0) {
        throw new SessionNotFoundError({
          message: `No connected Studio matches --target '${sessionId}'.`,
          fix: LIST_SESSIONS_FIX,
          sessionId,
        });
      }
      if (instanceIds.length > 1) {
        throw new SessionNotFoundError({
          message: `--target '${sessionId}' matches several Studios.`,
          fix: `Use a longer --target, one of: ${instanceIds.join(', ')}`,
          sessionId,
        });
      }
      return this._resolveByInstance(instanceIds[0], context);
    }

    if (instanceId) {
      return this._resolveByInstance(instanceId, context);
    }

    const instances = this.listInstances();

    if (instances.length === 0) {
      throw new SessionNotFoundError({
        code: NO_STUDIO_CONNECTED,
        message: 'No Studio is connected to studio-bridge.',
        fix: "Open a place in Studio with the studio-bridge plugin installed ('studio-bridge plugin install').",
      });
    }

    if (instances.length === 1) {
      return this._resolveByInstance(instances[0].instanceId, context);
    }

    // Multiple instances: list session IDs so the user can copy one into --target
    throw new SessionNotFoundError({
      message: 'Several Studios are connected, so this needs a --target.',
      fix: `Pick one with --target <id>:\n${formatSessionList(
        this.listSessions()
      )}`,
    });
  }

  /** Resolves with the first connected session. Rejects after timeout. */
  async waitForSessionAsync(timeout?: number): Promise<BridgeSession> {
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
        reject(
          new SessionNotFoundError({
            code: NO_STUDIO_CONNECTED,
            message: `No Studio connected within ${formatSeconds(timeoutMs)}.`,
            fix: "Open a place in Studio with the studio-bridge plugin installed ('studio-bridge plugin install').",
          })
        );
      }, timeoutMs);

      this.once('session-connected', onSession);
    });
  }

  private async _ensureSettledAsync(): Promise<void> {
    if (this._hasSettled) {
      return;
    }
    if (this._role === 'client') {
      this._hasSettled = true;
      await this._waitForNewHostDiscoveryAsync();
      return;
    }
    if (this.listSessions().length > 0) {
      return;
    }
    OutputHelper.verbose(
      '[bridge] No sessions yet — waiting for plugins to discover us'
    );
    await this.waitForSessionsToSettleAsync({
      firstSessionTimeout: this._firstSessionTimeoutMs,
    });
    this._hasSettled = true;
    const settled = this.listSessions();
    OutputHelper.verbose(
      `[bridge] Settled with ${settled.length} session(s)${
        settled.length > 0
          ? ': ' + settled.map((s) => s.sessionId).join(', ')
          : ''
      }`
    );
  }

  private async _waitForNewHostDiscoveryAsync(): Promise<void> {
    const uptimeMs = this._client?.hostInfo?.uptimeMs;
    if (uptimeMs === undefined) {
      return;
    }
    const hostStartedAt = this._clientConnectedAt - uptimeMs;
    const discoveredIn = hostStartedAt + PLUGIN_DISCOVERY_MS - Date.now();
    if (discoveredIn <= 0) {
      return;
    }
    OutputHelper.verbose(
      `[bridge] The host started ${uptimeMs}ms ago — waiting ${discoveredIn}ms for Studios to find it`
    );
    await new Promise((resolve) => setTimeout(resolve, discoveredIn));
    if (this.listSessions().length === 0) {
      const remaining =
        hostStartedAt + (this._firstSessionTimeoutMs ?? 5_000) - Date.now();
      if (remaining > 0) {
        await this.waitForSessionAsync(remaining).catch(() => undefined);
      }
    }
  }

  /**
   * Wait for all active Studios to discover this host and connect. Waits for
   * the first session, then keeps waiting until no new sessions arrive for a
   * full plugin poll cycle (~2.5s). Guarantees all polling plugins have had
   * a chance to find the host. Safe to call when not a host (returns immediately).
   */
  async waitForSessionsToSettleAsync(options?: {
    /** Max time to wait for the first session (ms). Default: 5000 */
    firstSessionTimeout?: number;
    /** How long to wait after the last connection before considering settled (ms). Default: 4000 */
    settleMs?: number;
    /** Absolute max wait time (ms). Default: 15000 */
    maxMs?: number;
  }): Promise<void> {
    if (this._role !== 'host') {
      return;
    }

    const firstTimeout = options?.firstSessionTimeout ?? 5_000;
    const settleMs = options?.settleMs ?? 4_000;
    const maxMs = options?.maxMs ?? Math.max(15_000, firstTimeout + settleMs);

    // Wait for the first session
    try {
      await this.waitForSessionAsync(firstTimeout);
    } catch {
      // No session appeared — nothing to settle
      return;
    }

    // Wait for sessions to stabilize: reset timer on each new connection
    await new Promise<void>((resolve) => {
      const cleanup = () => {
        clearTimeout(settleTimer);
        clearTimeout(maxTimer);
        this.off('session-connected', onSession);
        resolve();
      };

      const onSession = () => {
        clearTimeout(settleTimer);
        settleTimer = setTimeout(cleanup, settleMs);
      };

      let settleTimer = setTimeout(cleanup, settleMs);
      const maxTimer = setTimeout(cleanup, maxMs);

      this.on('session-connected', onSession);
    });
  }

  private async _initHostAsync(port: number): Promise<void> {
    this._hostBuild = await getHostBuildAsync();
    this._host = new BridgeHost();
    this._tracker = new SessionTracker();
    this._host.on('client-activity', () => this.emit('client-activity'));

    this._tracker.on('session-added', (tracked: TrackedSession) => {
      const session = new BridgeSession(tracked.info, tracked.handle);
      this._hostSessions.set(tracked.info.sessionId, session);
      this.emit('session-connected', session);
      this._resetIdleTimer();

      this._host?.broadcastToClients({
        type: 'session-event',
        event: 'connected',
        sessionId: tracked.info.sessionId,
        session: tracked.info,
        context: tracked.info.context,
        instanceId: tracked.info.instanceId,
      });
    });

    this._tracker.on('session-removed', (sessionId: string) => {
      const removed = this._hostSessions.get(sessionId);
      this._hostSessions.delete(sessionId);
      this._hostHandles.delete(sessionId);
      this.emit('session-disconnected', sessionId);
      this._resetIdleTimer();

      this._host?.broadcastToClients({
        type: 'session-event',
        event: 'disconnected',
        sessionId,
        context: removed?.info.context ?? 'edit',
        instanceId: removed?.info.instanceId ?? sessionId,
      });
    });

    this._tracker.on('instance-added', (instance: InstanceInfo) => {
      this.emit('instance-connected', instance);
    });

    this._tracker.on('instance-removed', (instanceId: string) => {
      this.emit('instance-disconnected', instanceId);
    });

    this._host.on('plugin-connected', (info) => {
      const state = info.state ?? 'Edit';
      const context = info.context ?? BridgeConnection._deriveContext(state);

      const sessionInfo: SessionInfo = {
        sessionId: info.sessionId,
        placeName: info.placeName ?? '',
        placeFile: info.placeFile,
        state: state as SessionInfo['state'],
        pluginVersion: info.pluginVersion ?? '',
        capabilities: info.capabilities,
        connectedAt: new Date(),
        origin: info.launchId ? 'managed' : 'user',
        launchId: info.launchId,
        playerName: info.playerName,
        playtestId: info.playtestId,
        context,
        instanceId: info.instanceId ?? info.sessionId,
        placeId: 0,
        gameId: 0,
      };

      const handle = new HostTransportHandle(info.sessionId, this._host!);
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

    // Handle client protocol messages (list-sessions, list-instances, etc.)
    this._host.on(
      'client-message',
      (msg: HostProtocolMessage, reply: (m: HostProtocolMessage) => void) => {
        if (msg.type === 'list-sessions') {
          const req = msg as ListSessionsRequest;
          reply({
            type: 'list-sessions-response',
            requestId: req.requestId,
            sessions: this._tracker!.listSessions(),
            protocolVersion: HOST_PROTOCOL_VERSION,
            host: this._describeHost(),
          });
        } else if (msg.type === 'list-instances') {
          const req = msg as ListInstancesRequest;
          reply({
            type: 'list-instances-response',
            requestId: req.requestId,
            instances: this._tracker!.listInstances(),
          });
        } else if (msg.type === 'host-envelope') {
          const relay = this._relayEnvelopeAsync(msg as HostEnvelope, reply);
          this._pendingRelays.add(relay);
          void relay.finally(() => this._pendingRelays.delete(relay));
        }
      }
    );

    await this._host.startAsync({ port });
    this._hostStartedAt = Date.now();
    this._isConnected = true;
    // Don't start idle timer on init -- callers like `sessions` manage their
    // own lifecycle via disconnectAsync().  The idle timer should only fire
    // when sessions are removed (going from >0 to 0).
  }

  private _describeHost(): HostInfo {
    return {
      version: this._hostBuild?.version ?? 'unknown',
      build: this._hostBuild?.build,
      packagePath: this._hostBuild?.packagePath,
      cwd: process.cwd(),
      pid: process.pid,
      argv: process.argv.slice(2),
      clients: this._host?.clientCount ?? 0,
      pendingRelays: this._pendingRelays.size,
      uptimeMs: Date.now() - this._hostStartedAt,
      ...this._hostDetails,
    };
  }

  private async _relayEnvelopeAsync(
    envelope: HostEnvelope,
    reply: (m: HostProtocolMessage) => void
  ): Promise<void> {
    const sessionId = envelope.targetSessionId;
    const handle = this._hostHandles.get(sessionId);

    if (envelope.timeoutMs === undefined) {
      handle?.sendMessage(envelope.action);
      return;
    }

    let result: PluginMessage;
    if (!handle) {
      result = {
        type: 'error',
        sessionId,
        payload: {
          code: 'SESSION_MISMATCH',
          message: `Session '${sessionId}' is not connected to this host`,
        },
      };
    } else {
      try {
        result = await handle.sendActionAsync<PluginMessage>(
          envelope.action,
          envelope.timeoutMs
        );
      } catch (err) {
        result = {
          type: 'error',
          sessionId,
          payload: {
            code:
              err instanceof RequestTimeoutError ? 'TIMEOUT' : 'INTERNAL_ERROR',
            message: err instanceof Error ? err.message : String(err),
          },
        };
      }
    }

    reply({ type: 'host-response', requestId: envelope.requestId, result });
  }

  private async _initClientAsync(
    port: number,
    remoteHost?: string
  ): Promise<void> {
    this._client = new BridgeClient();

    this._client.on('session-connected', (session: BridgeSession) => {
      this.emit('session-connected', session);
    });

    this._client.on('session-disconnected', (sessionId: string) => {
      this.emit('session-disconnected', sessionId);
    });

    this._client.on('disconnected', () => {
      this._isConnected = false;
    });

    this._client.on('host-promoted', () => {
      this._role = 'host';
    });

    const host = remoteHost ? remoteHost.split(':')[0] : undefined;
    await this._client.connectAsync(port, host);
    this._clientConnectedAt = Date.now();
    this._clientPort = port;
    this._isConnected = true;
  }

  private async _checkStaleHostAsync(
    options: BridgeConnectionOptions
  ): Promise<BridgeConnection | undefined> {
    const host = this._client?.hostInfo;
    const ours = await getHostBuildAsync();
    const verdict = assessHost(host, ours);
    if (verdict.action === 'current') {
      return undefined;
    }

    const builds = {
      port: this.port,
      hostBuild: describeHostBuild(host),
      ourBuild: describeHostBuild(ours),
      isOlder: verdict.action === 'replace',
    };
    const leave = (outcome: StaleHostOutcome): undefined => {
      this._staleHost = describeStaleHost(outcome, builds);
      return undefined;
    };

    if (verdict.action === 'warn') {
      return leave(
        verdict.reason === 'other-install'
          ? { kind: 'other-install' }
          : { kind: 'unreadable', pid: host?.pid }
      );
    }

    if (this._isRemote) {
      return leave({ kind: 'remote' });
    }
    const stale = host
      ? staleHostFromInfo(host)
      : await tryFindLegacyHostAsync(this.port);
    if (!stale) {
      return leave({ kind: 'process-unknown' });
    }
    if (!isServeArgv(stale.argv)) {
      return leave({ kind: 'inside-command', pid: stale.pid });
    }
    if (!stale.cwd && argvDependsOnCwd(stale.argv)) {
      return leave({ kind: 'unknown-cwd', pid: stale.pid });
    }
    if (stale.inUse) {
      return leave({ kind: 'in-use' });
    }

    const sessionIds = this.listSessions().map((s) => s.sessionId);
    await this.disconnectAsync();
    let outcome: StaleHostOutcome;
    try {
      const pid = await replaceHostAsync(this.port, stale);
      OutputHelper.verbose(
        `[bridge] Replaced the bridge host on port ${this.port}: pid ${
          stale.pid
        } -> ${pid ?? '?'}`
      );
      outcome = { kind: 'restarted' };
    } catch (error) {
      outcome = { kind: 'restart-failed', pid: stale.pid, error };
    }

    const conn = await BridgeConnection.connectAsync({
      ...options,
      port: this.port,
      local: true,
      replaceStaleHost: false,
    });
    if (outcome.kind === 'restarted') {
      await conn._waitForSessionIdsAsync(sessionIds);
    }
    conn._staleHost = describeStaleHost(outcome, builds);
    return conn;
  }

  private async _waitForSessionIdsAsync(sessionIds: string[]): Promise<void> {
    const deadline = Date.now() + SESSION_RECONNECT_TIMEOUT_MS;
    while (Date.now() < deadline) {
      const live = new Set(this.listSessions().map((s) => s.sessionId));
      if (sessionIds.every((id) => live.has(id))) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }

  private static _deriveContext(state: string): SessionContext {
    if (state === 'Server') return 'server';
    if (state === 'Client') return 'client';
    return 'edit';
  }

  private _resolveByInstance(
    instanceId: string,
    context?: SessionContext
  ): BridgeSession {
    const sessions = this.listSessions().filter(
      (s) => s.instanceId === instanceId
    );

    if (sessions.length === 0) {
      throw new SessionNotFoundError({
        message: `No connected Studio matches '${instanceId}'.`,
        fix: LIST_SESSIONS_FIX,
      });
    }

    const contexts = sessions.map((s) => s.context);

    // 5a: Context specified
    if (context) {
      const matches = sessions.filter((s) => s.context === context);
      if (matches.length > 1) {
        throw new SessionNotFoundError({
          message: `This Studio has several ${context} sessions, so this needs a session id.`,
          fix: `Pick one with --target <id>:\n${formatSessionList(matches)}`,
        });
      }
      const match = matches[0];
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

    throw new SessionNotFoundError({
      message: `No connected Studio matches '${instanceId}'.`,
      fix: LIST_SESSIONS_FIX,
    });
  }

  private _resetIdleTimer(): void {
    if (this._keepAlive) {
      return;
    }

    this._clearIdleTimer();

    // Only start idle timer if we're the host and have no sessions
    if (this._role === 'host' && this._tracker) {
      if (this._tracker.sessionCount === 0) {
        OutputHelper.verbose(
          `[bridge] Starting idle exit timer (${IDLE_EXIT_GRACE_MS}ms, sessionCount=0)`
        );
        this._idleTimer = setTimeout(() => {
          OutputHelper.verbose(
            '[bridge] Idle exit timer fired — disconnecting'
          );
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
