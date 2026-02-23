/**
 * In-memory session map with instance-level grouping. Tracks connected
 * plugin sessions by sessionId and groups them by instanceId for
 * multi-context support (edit, client, server in Play mode).
 *
 * Used exclusively by bridge-host.ts. Emits events when sessions and
 * instance groups are added, removed, or updated.
 */

import { EventEmitter } from 'events';
import type {
  SessionInfo,
  SessionContext,
  InstanceInfo,
  StudioState,
} from '../types.js';
import type { PluginMessage, ServerMessage } from '../../server/web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface TransportHandle {
  sendActionAsync<TResponse>(message: ServerMessage, timeoutMs: number): Promise<TResponse>;
  sendMessage(message: ServerMessage): void;
  readonly isConnected: boolean;
  on(event: 'message', listener: (msg: PluginMessage) => void): this;
  on(event: 'disconnected', listener: () => void): this;
}

export interface TrackedSession {
  info: SessionInfo;
  handle: TransportHandle;
  lastHeartbeat: Date;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

export class SessionTracker extends EventEmitter {
  private _sessions = new Map<string, TrackedSession>();
  private _instanceSessions = new Map<string, Set<string>>();

  /**
   * Add a session to the tracker. Groups by instanceId and emits events.
   * If this is the first session for the instanceId, emits 'instance-added'.
   */
  addSession(sessionId: string, info: SessionInfo, handle: TransportHandle): void {
    const tracked: TrackedSession = {
      info,
      handle,
      lastHeartbeat: new Date(),
    };

    this._sessions.set(sessionId, tracked);

    // Instance grouping
    const instanceId = info.instanceId;
    let sessionSet = this._instanceSessions.get(instanceId);
    const isNewInstance = !sessionSet;

    if (!sessionSet) {
      sessionSet = new Set();
      this._instanceSessions.set(instanceId, sessionSet);
    }

    sessionSet.add(sessionId);

    this.emit('session-added', tracked);

    if (isNewInstance) {
      this.emit('instance-added', this._buildInstanceInfo(instanceId));
    }
  }

  /**
   * Remove a session from the tracker. If this was the last session for
   * the instanceId, removes the instance group and emits 'instance-removed'.
   */
  removeSession(sessionId: string): void {
    const tracked = this._sessions.get(sessionId);
    if (!tracked) {
      return;
    }

    const instanceId = tracked.info.instanceId;
    this._sessions.delete(sessionId);

    // Update instance grouping
    const sessionSet = this._instanceSessions.get(instanceId);
    if (sessionSet) {
      sessionSet.delete(sessionId);

      if (sessionSet.size === 0) {
        this._instanceSessions.delete(instanceId);
        this.emit('session-removed', sessionId);
        this.emit('instance-removed', instanceId);
        return;
      }
    }

    this.emit('session-removed', sessionId);
  }

  /**
   * Get a tracked session by sessionId.
   */
  getSession(sessionId: string): TrackedSession | undefined {
    return this._sessions.get(sessionId);
  }

  /**
   * List all session infos.
   */
  listSessions(): SessionInfo[] {
    return Array.from(this._sessions.values()).map((t) => t.info);
  }

  /**
   * Update a session's state and emit 'session-updated'.
   */
  updateSessionState(sessionId: string, state: StudioState): void {
    const tracked = this._sessions.get(sessionId);
    if (!tracked) {
      return;
    }

    tracked.info = { ...tracked.info, state };
    this.emit('session-updated', tracked);
  }

  /**
   * List unique instances. Each instance groups 1-3 context sessions
   * that share the same instanceId.
   */
  listInstances(): InstanceInfo[] {
    const instances: InstanceInfo[] = [];

    for (const instanceId of this._instanceSessions.keys()) {
      instances.push(this._buildInstanceInfo(instanceId));
    }

    return instances;
  }

  /**
   * Get all tracked sessions for a given instanceId.
   */
  getSessionsByInstance(instanceId: string): TrackedSession[] {
    const sessionIds = this._instanceSessions.get(instanceId);
    if (!sessionIds) {
      return [];
    }

    const result: TrackedSession[] = [];
    for (const sessionId of sessionIds) {
      const tracked = this._sessions.get(sessionId);
      if (tracked) {
        result.push(tracked);
      }
    }
    return result;
  }

  /**
   * Get a specific context session for an instance.
   * Returns undefined if the context is not connected.
   */
  getSessionByContext(
    instanceId: string,
    context: SessionContext,
  ): TrackedSession | undefined {
    const sessions = this.getSessionsByInstance(instanceId);
    return sessions.find((s) => s.info.context === context);
  }

  /** Number of currently tracked sessions. */
  get sessionCount(): number {
    return this._sessions.size;
  }

  // -------------------------------------------------------------------------
  // Private
  // -------------------------------------------------------------------------

  private _buildInstanceInfo(instanceId: string): InstanceInfo {
    const sessions = this.getSessionsByInstance(instanceId);
    const first = sessions[0];

    return {
      instanceId,
      placeName: first?.info.placeName ?? '',
      placeId: first?.info.placeId ?? 0,
      gameId: first?.info.gameId ?? 0,
      contexts: sessions.map((s) => s.info.context),
      origin: first?.info.origin ?? 'user',
    };
  }
}
