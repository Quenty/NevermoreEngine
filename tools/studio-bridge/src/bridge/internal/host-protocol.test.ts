/**
 * Unit tests for host-protocol -- validates encode/decode round-trip
 * for all envelope message types.
 */

import { describe, it, expect } from 'vitest';
import {
  encodeHostMessage,
  decodeHostMessage,
  type HostEnvelope,
  type ListSessionsRequest,
  type ListInstancesRequest,
  type HostResponse,
  type ListSessionsResponse,
  type ListInstancesResponse,
  type SessionEvent,
  type HostProtocolMessage,
} from './host-protocol.js';
import type { SessionInfo, InstanceInfo } from '../types.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function roundTrip(msg: HostProtocolMessage): HostProtocolMessage | null {
  return decodeHostMessage(encodeHostMessage(msg));
}

function createSessionInfo(overrides: Partial<SessionInfo> = {}): SessionInfo {
  return {
    sessionId: 'session-1',
    placeName: 'TestPlace',
    state: 'Edit',
    pluginVersion: '1.0.0',
    capabilities: ['execute'],
    connectedAt: new Date('2024-01-01'),
    origin: 'user',
    context: 'edit',
    instanceId: 'inst-1',
    placeId: 100,
    gameId: 200,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('host-protocol', () => {
  // -----------------------------------------------------------------------
  // HostEnvelope
  // -----------------------------------------------------------------------

  describe('HostEnvelope', () => {
    it('round-trips correctly', () => {
      const msg: HostEnvelope = {
        type: 'host-envelope',
        requestId: 'req-1',
        targetSessionId: 'session-1',
        action: {
          type: 'execute',
          sessionId: 'session-1',
          payload: { script: 'print("hi")' },
        },
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('host-envelope');
      const envelope = decoded as HostEnvelope;
      expect(envelope.requestId).toBe('req-1');
      expect(envelope.targetSessionId).toBe('session-1');
      expect(envelope.action.type).toBe('execute');
    });
  });

  // -----------------------------------------------------------------------
  // ListSessionsRequest
  // -----------------------------------------------------------------------

  describe('ListSessionsRequest', () => {
    it('round-trips correctly', () => {
      const msg: ListSessionsRequest = {
        type: 'list-sessions',
        requestId: 'req-2',
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('list-sessions');
      expect((decoded as ListSessionsRequest).requestId).toBe('req-2');
    });
  });

  // -----------------------------------------------------------------------
  // ListInstancesRequest
  // -----------------------------------------------------------------------

  describe('ListInstancesRequest', () => {
    it('round-trips correctly', () => {
      const msg: ListInstancesRequest = {
        type: 'list-instances',
        requestId: 'req-3',
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('list-instances');
      expect((decoded as ListInstancesRequest).requestId).toBe('req-3');
    });
  });

  // -----------------------------------------------------------------------
  // HostResponse
  // -----------------------------------------------------------------------

  describe('HostResponse', () => {
    it('round-trips correctly', () => {
      const msg: HostResponse = {
        type: 'host-response',
        requestId: 'req-4',
        result: {
          type: 'stateResult',
          sessionId: 'session-1',
          requestId: 'req-4',
          payload: {
            state: 'Edit',
            placeId: 100,
            placeName: 'Test',
            gameId: 200,
          },
        },
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('host-response');
      const response = decoded as HostResponse;
      expect(response.requestId).toBe('req-4');
      expect(response.result.type).toBe('stateResult');
    });
  });

  // -----------------------------------------------------------------------
  // ListSessionsResponse
  // -----------------------------------------------------------------------

  describe('ListSessionsResponse', () => {
    it('round-trips correctly', () => {
      const msg: ListSessionsResponse = {
        type: 'list-sessions-response',
        requestId: 'req-5',
        sessions: [createSessionInfo()],
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('list-sessions-response');
      const response = decoded as ListSessionsResponse;
      expect(response.requestId).toBe('req-5');
      expect(response.sessions).toHaveLength(1);
      expect(response.sessions[0].sessionId).toBe('session-1');
    });

    it('handles empty session list', () => {
      const msg: ListSessionsResponse = {
        type: 'list-sessions-response',
        requestId: 'req-6',
        sessions: [],
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect((decoded as ListSessionsResponse).sessions).toHaveLength(0);
    });
  });

  // -----------------------------------------------------------------------
  // ListInstancesResponse
  // -----------------------------------------------------------------------

  describe('ListInstancesResponse', () => {
    it('round-trips correctly', () => {
      const instance: InstanceInfo = {
        instanceId: 'inst-1',
        placeName: 'TestPlace',
        placeId: 100,
        gameId: 200,
        contexts: ['edit', 'server'],
        origin: 'user',
      };

      const msg: ListInstancesResponse = {
        type: 'list-instances-response',
        requestId: 'req-7',
        instances: [instance],
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('list-instances-response');
      const response = decoded as ListInstancesResponse;
      expect(response.instances).toHaveLength(1);
      expect(response.instances[0].instanceId).toBe('inst-1');
    });
  });

  // -----------------------------------------------------------------------
  // SessionEvent
  // -----------------------------------------------------------------------

  describe('SessionEvent', () => {
    it('round-trips connected event', () => {
      const msg: SessionEvent = {
        type: 'session-event',
        event: 'connected',
        session: createSessionInfo(),
        sessionId: 'session-1',
        context: 'edit',
        instanceId: 'inst-1',
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('session-event');
      const event = decoded as SessionEvent;
      expect(event.event).toBe('connected');
      expect(event.session).toBeDefined();
      expect(event.sessionId).toBe('session-1');
      expect(event.context).toBe('edit');
      expect(event.instanceId).toBe('inst-1');
    });

    it('round-trips disconnected event (no session)', () => {
      const msg: SessionEvent = {
        type: 'session-event',
        event: 'disconnected',
        sessionId: 'session-1',
        context: 'edit',
        instanceId: 'inst-1',
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      const event = decoded as SessionEvent;
      expect(event.event).toBe('disconnected');
      expect(event.session).toBeUndefined();
    });

    it('round-trips state-changed event', () => {
      const msg: SessionEvent = {
        type: 'session-event',
        event: 'state-changed',
        session: createSessionInfo({ state: 'Play' }),
        sessionId: 'session-1',
        context: 'edit',
        instanceId: 'inst-1',
      };

      const decoded = roundTrip(msg);

      expect(decoded).not.toBeNull();
      expect((decoded as SessionEvent).event).toBe('state-changed');
    });
  });

  // -----------------------------------------------------------------------
  // Error handling
  // -----------------------------------------------------------------------

  describe('error handling', () => {
    it('returns null for invalid JSON', () => {
      expect(decodeHostMessage('not json')).toBeNull();
    });

    it('returns null for non-object values', () => {
      expect(decodeHostMessage('"hello"')).toBeNull();
      expect(decodeHostMessage('42')).toBeNull();
      expect(decodeHostMessage('null')).toBeNull();
    });

    it('returns null for missing type', () => {
      expect(decodeHostMessage(JSON.stringify({ requestId: 'r-1' }))).toBeNull();
    });

    it('returns null for unknown type', () => {
      expect(decodeHostMessage(JSON.stringify({ type: 'unknown' }))).toBeNull();
    });

    it('returns null for host-envelope with missing fields', () => {
      expect(decodeHostMessage(JSON.stringify({
        type: 'host-envelope',
        requestId: 'r-1',
        // missing targetSessionId and action
      }))).toBeNull();
    });

    it('returns null for list-sessions with missing requestId', () => {
      expect(decodeHostMessage(JSON.stringify({
        type: 'list-sessions',
      }))).toBeNull();
    });

    it('returns null for session-event with invalid event value', () => {
      expect(decodeHostMessage(JSON.stringify({
        type: 'session-event',
        event: 'invalid',
        sessionId: 's-1',
        context: 'edit',
        instanceId: 'i-1',
      }))).toBeNull();
    });
  });
});
