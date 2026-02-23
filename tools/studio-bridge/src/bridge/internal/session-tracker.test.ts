/**
 * Unit tests for SessionTracker -- validates session add/remove,
 * instance grouping, event emission, state updates, and context queries.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { SessionTracker, type TransportHandle, type TrackedSession } from './session-tracker.js';
import type { SessionInfo, InstanceInfo, SessionContext } from '../types.js';
import type { PluginMessage, ServerMessage } from '../../server/web-socket-protocol.js';
import { EventEmitter } from 'events';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockHandle(connected = true): TransportHandle {
  const emitter = new EventEmitter();
  return {
    sendActionAsync: vi.fn(async () => ({}) as any),
    sendMessage: vi.fn(),
    isConnected: connected,
    on: emitter.on.bind(emitter) as TransportHandle['on'],
  };
}

function createSessionInfo(overrides: Partial<SessionInfo> = {}): SessionInfo {
  return {
    sessionId: 'session-1',
    placeName: 'TestPlace',
    state: 'Edit',
    pluginVersion: '1.0.0',
    capabilities: ['execute', 'queryState'],
    connectedAt: new Date(),
    origin: 'user',
    context: 'edit',
    instanceId: 'inst-1',
    placeId: 123,
    gameId: 456,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('SessionTracker', () => {
  let tracker: SessionTracker;

  beforeEach(() => {
    tracker = new SessionTracker();
  });

  // -----------------------------------------------------------------------
  // Add session
  // -----------------------------------------------------------------------

  describe('addSession', () => {
    it('adds a session and increments sessionCount', () => {
      const info = createSessionInfo();
      const handle = createMockHandle();

      tracker.addSession('session-1', info, handle);

      expect(tracker.sessionCount).toBe(1);
    });

    it('emits session-added event with tracked session', () => {
      const info = createSessionInfo();
      const handle = createMockHandle();
      const listener = vi.fn();

      tracker.on('session-added', listener);
      tracker.addSession('session-1', info, handle);

      expect(listener).toHaveBeenCalledTimes(1);
      const tracked = listener.mock.calls[0][0] as TrackedSession;
      expect(tracked.info.sessionId).toBe('session-1');
      expect(tracked.handle).toBe(handle);
    });

    it('emits instance-added on first session for an instanceId', () => {
      const info = createSessionInfo({ instanceId: 'inst-A' });
      const handle = createMockHandle();
      const listener = vi.fn();

      tracker.on('instance-added', listener);
      tracker.addSession('session-1', info, handle);

      expect(listener).toHaveBeenCalledTimes(1);
      const instance = listener.mock.calls[0][0] as InstanceInfo;
      expect(instance.instanceId).toBe('inst-A');
      expect(instance.contexts).toEqual(['edit']);
    });

    it('does not emit instance-added for subsequent sessions on same instanceId', () => {
      const handle = createMockHandle();
      const listener = vi.fn();

      tracker.on('instance-added', listener);

      tracker.addSession(
        'session-edit',
        createSessionInfo({ sessionId: 'session-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );
      tracker.addSession(
        'session-server',
        createSessionInfo({ sessionId: 'session-server', instanceId: 'inst-A', context: 'server' }),
        handle,
      );

      expect(listener).toHaveBeenCalledTimes(1);
    });

    it('tracks multiple sessions', () => {
      const handle = createMockHandle();

      tracker.addSession('s1', createSessionInfo({ sessionId: 's1' }), handle);
      tracker.addSession('s2', createSessionInfo({ sessionId: 's2', instanceId: 'inst-2' }), handle);

      expect(tracker.sessionCount).toBe(2);
    });
  });

  // -----------------------------------------------------------------------
  // Remove session
  // -----------------------------------------------------------------------

  describe('removeSession', () => {
    it('removes a session and decrements sessionCount', () => {
      const handle = createMockHandle();
      tracker.addSession('s1', createSessionInfo({ sessionId: 's1' }), handle);

      tracker.removeSession('s1');

      expect(tracker.sessionCount).toBe(0);
    });

    it('emits session-removed with sessionId', () => {
      const handle = createMockHandle();
      tracker.addSession('s1', createSessionInfo({ sessionId: 's1' }), handle);

      const listener = vi.fn();
      tracker.on('session-removed', listener);

      tracker.removeSession('s1');

      expect(listener).toHaveBeenCalledWith('s1');
    });

    it('emits instance-removed when last session for instanceId is removed', () => {
      const handle = createMockHandle();
      tracker.addSession(
        's1',
        createSessionInfo({ sessionId: 's1', instanceId: 'inst-A' }),
        handle,
      );

      const listener = vi.fn();
      tracker.on('instance-removed', listener);

      tracker.removeSession('s1');

      expect(listener).toHaveBeenCalledWith('inst-A');
    });

    it('does not emit instance-removed when other sessions remain for instanceId', () => {
      const handle = createMockHandle();
      tracker.addSession(
        's-edit',
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );
      tracker.addSession(
        's-server',
        createSessionInfo({ sessionId: 's-server', instanceId: 'inst-A', context: 'server' }),
        handle,
      );

      const listener = vi.fn();
      tracker.on('instance-removed', listener);

      tracker.removeSession('s-server');

      expect(listener).not.toHaveBeenCalled();
      expect(tracker.sessionCount).toBe(1);
    });

    it('is a no-op for unknown sessionId', () => {
      const listener = vi.fn();
      tracker.on('session-removed', listener);

      tracker.removeSession('nonexistent');

      expect(listener).not.toHaveBeenCalled();
    });
  });

  // -----------------------------------------------------------------------
  // Get session
  // -----------------------------------------------------------------------

  describe('getSession', () => {
    it('returns tracked session by id', () => {
      const info = createSessionInfo({ sessionId: 's1' });
      const handle = createMockHandle();
      tracker.addSession('s1', info, handle);

      const tracked = tracker.getSession('s1');

      expect(tracked).toBeDefined();
      expect(tracked!.info.sessionId).toBe('s1');
      expect(tracked!.handle).toBe(handle);
    });

    it('returns undefined for unknown id', () => {
      expect(tracker.getSession('nonexistent')).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // List sessions
  // -----------------------------------------------------------------------

  describe('listSessions', () => {
    it('returns empty array when no sessions', () => {
      expect(tracker.listSessions()).toEqual([]);
    });

    it('returns all session infos', () => {
      const handle = createMockHandle();
      tracker.addSession('s1', createSessionInfo({ sessionId: 's1' }), handle);
      tracker.addSession('s2', createSessionInfo({ sessionId: 's2', instanceId: 'inst-2' }), handle);

      const sessions = tracker.listSessions();

      expect(sessions).toHaveLength(2);
      expect(sessions.map((s) => s.sessionId).sort()).toEqual(['s1', 's2']);
    });
  });

  // -----------------------------------------------------------------------
  // Update session state
  // -----------------------------------------------------------------------

  describe('updateSessionState', () => {
    it('updates state and emits session-updated', () => {
      const handle = createMockHandle();
      tracker.addSession('s1', createSessionInfo({ sessionId: 's1', state: 'Edit' }), handle);

      const listener = vi.fn();
      tracker.on('session-updated', listener);

      tracker.updateSessionState('s1', 'Play');

      const tracked = tracker.getSession('s1');
      expect(tracked!.info.state).toBe('Play');
      expect(listener).toHaveBeenCalledTimes(1);
      expect((listener.mock.calls[0][0] as TrackedSession).info.state).toBe('Play');
    });

    it('is a no-op for unknown sessionId', () => {
      const listener = vi.fn();
      tracker.on('session-updated', listener);

      tracker.updateSessionState('nonexistent', 'Play');

      expect(listener).not.toHaveBeenCalled();
    });
  });

  // -----------------------------------------------------------------------
  // Instance grouping
  // -----------------------------------------------------------------------

  describe('listInstances', () => {
    it('returns empty array when no sessions', () => {
      expect(tracker.listInstances()).toEqual([]);
    });

    it('groups sessions by instanceId', () => {
      const handle = createMockHandle();

      tracker.addSession(
        's-edit',
        createSessionInfo({
          sessionId: 's-edit',
          instanceId: 'inst-A',
          context: 'edit',
          placeName: 'MyPlace',
          placeId: 100,
          gameId: 200,
        }),
        handle,
      );
      tracker.addSession(
        's-server',
        createSessionInfo({
          sessionId: 's-server',
          instanceId: 'inst-A',
          context: 'server',
        }),
        handle,
      );
      tracker.addSession(
        's-client',
        createSessionInfo({
          sessionId: 's-client',
          instanceId: 'inst-A',
          context: 'client',
        }),
        handle,
      );

      const instances = tracker.listInstances();

      expect(instances).toHaveLength(1);
      expect(instances[0].instanceId).toBe('inst-A');
      expect(instances[0].contexts.sort()).toEqual(['client', 'edit', 'server']);
    });

    it('returns multiple instances for different instanceIds', () => {
      const handle = createMockHandle();

      tracker.addSession(
        's1',
        createSessionInfo({ sessionId: 's1', instanceId: 'inst-A' }),
        handle,
      );
      tracker.addSession(
        's2',
        createSessionInfo({ sessionId: 's2', instanceId: 'inst-B' }),
        handle,
      );

      const instances = tracker.listInstances();

      expect(instances).toHaveLength(2);
      const ids = instances.map((i) => i.instanceId).sort();
      expect(ids).toEqual(['inst-A', 'inst-B']);
    });
  });

  describe('getSessionsByInstance', () => {
    it('returns all sessions for an instanceId', () => {
      const handle = createMockHandle();

      tracker.addSession(
        's-edit',
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );
      tracker.addSession(
        's-server',
        createSessionInfo({ sessionId: 's-server', instanceId: 'inst-A', context: 'server' }),
        handle,
      );

      const sessions = tracker.getSessionsByInstance('inst-A');

      expect(sessions).toHaveLength(2);
    });

    it('returns empty array for unknown instanceId', () => {
      expect(tracker.getSessionsByInstance('nonexistent')).toEqual([]);
    });
  });

  describe('getSessionByContext', () => {
    it('returns the session matching the context', () => {
      const handle = createMockHandle();

      tracker.addSession(
        's-edit',
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );
      tracker.addSession(
        's-server',
        createSessionInfo({ sessionId: 's-server', instanceId: 'inst-A', context: 'server' }),
        handle,
      );

      const session = tracker.getSessionByContext('inst-A', 'server');

      expect(session).toBeDefined();
      expect(session!.info.sessionId).toBe('s-server');
    });

    it('returns undefined when context is not connected', () => {
      const handle = createMockHandle();

      tracker.addSession(
        's-edit',
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );

      const session = tracker.getSessionByContext('inst-A', 'client');

      expect(session).toBeUndefined();
    });

    it('returns undefined for unknown instanceId', () => {
      expect(tracker.getSessionByContext('nonexistent', 'edit')).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Instance lifecycle with add/remove
  // -----------------------------------------------------------------------

  describe('instance lifecycle', () => {
    it('instance-added fires once then contexts update without new event', () => {
      const handle = createMockHandle();
      const instanceAdded = vi.fn();
      tracker.on('instance-added', instanceAdded);

      // First session -> instance-added
      tracker.addSession(
        's-edit',
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );
      expect(instanceAdded).toHaveBeenCalledTimes(1);

      // Second session -> no instance-added
      tracker.addSession(
        's-server',
        createSessionInfo({ sessionId: 's-server', instanceId: 'inst-A', context: 'server' }),
        handle,
      );
      expect(instanceAdded).toHaveBeenCalledTimes(1);

      // Instance contexts should reflect both
      const instances = tracker.listInstances();
      expect(instances[0].contexts.sort()).toEqual(['edit', 'server']);
    });

    it('removing one context updates instance but does not remove it', () => {
      const handle = createMockHandle();
      const instanceRemoved = vi.fn();
      tracker.on('instance-removed', instanceRemoved);

      tracker.addSession(
        's-edit',
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );
      tracker.addSession(
        's-server',
        createSessionInfo({ sessionId: 's-server', instanceId: 'inst-A', context: 'server' }),
        handle,
      );

      tracker.removeSession('s-server');

      expect(instanceRemoved).not.toHaveBeenCalled();
      const instances = tracker.listInstances();
      expect(instances).toHaveLength(1);
      expect(instances[0].contexts).toEqual(['edit']);
    });

    it('removing all contexts for an instance fires instance-removed', () => {
      const handle = createMockHandle();
      const instanceRemoved = vi.fn();
      tracker.on('instance-removed', instanceRemoved);

      tracker.addSession(
        's-edit',
        createSessionInfo({ sessionId: 's-edit', instanceId: 'inst-A', context: 'edit' }),
        handle,
      );
      tracker.addSession(
        's-server',
        createSessionInfo({ sessionId: 's-server', instanceId: 'inst-A', context: 'server' }),
        handle,
      );

      tracker.removeSession('s-edit');
      expect(instanceRemoved).not.toHaveBeenCalled();

      tracker.removeSession('s-server');
      expect(instanceRemoved).toHaveBeenCalledWith('inst-A');
    });
  });
});
