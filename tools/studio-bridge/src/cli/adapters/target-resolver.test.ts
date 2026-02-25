/**
 * Unit tests for the target resolver.
 */

import { describe, it, expect, vi } from 'vitest';
import {
  resolveTargetAsync,
  TargetRequiredError,
} from './target-resolver.js';
import type { SessionInfo } from '../../bridge/index.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function mockSessionInfo(overrides: Partial<SessionInfo> = {}): SessionInfo {
  return {
    sessionId: overrides.sessionId ?? 'sess-1',
    placeName: overrides.placeName ?? 'TestPlace',
    state: 'Edit' as any,
    pluginVersion: '1.0.0',
    capabilities: [],
    connectedAt: new Date(),
    origin: 'user',
    context: overrides.context ?? 'edit',
    instanceId: overrides.instanceId ?? 'inst-1',
    placeId: overrides.placeId ?? 123,
    gameId: overrides.gameId ?? 456,
  };
}

function mockConnection(sessions: SessionInfo[] = []) {
  const sessionMap = new Map(sessions.map((s) => [s.sessionId, s]));

  return {
    listSessions: vi.fn().mockReturnValue(sessions),
    getSession: vi.fn((id: string) => sessionMap.get(id)),
    resolveSessionAsync: vi.fn(async (id: string) => {
      const info = sessionMap.get(id);
      if (!info) throw new Error(`Session '${id}' not found`);
      return info;
    }),
  } as any;
}

// ---------------------------------------------------------------------------
// Explicit target
// ---------------------------------------------------------------------------

describe('resolveTargetAsync', () => {
  describe('explicit --target', () => {
    it('resolves a specific session by ID', async () => {
      const sess = mockSessionInfo({ sessionId: 'abc-123' });
      const conn = mockConnection([sess]);

      const result = await resolveTargetAsync(conn, {
        target: 'abc-123',
        safety: 'mutate',
      });

      expect(result.sessions).toHaveLength(1);
      expect(conn.resolveSessionAsync).toHaveBeenCalledWith(
        'abc-123',
        undefined,
      );
    });

    it('passes context to resolveSessionAsync', async () => {
      const sess = mockSessionInfo({ sessionId: 'abc-123' });
      const conn = mockConnection([sess]);

      await resolveTargetAsync(conn, {
        target: 'abc-123',
        context: 'edit',
        safety: 'mutate',
      });

      expect(conn.resolveSessionAsync).toHaveBeenCalledWith(
        'abc-123',
        'edit',
      );
    });

    it('throws when session ID not found', async () => {
      const conn = mockConnection([]);

      await expect(
        resolveTargetAsync(conn, {
          target: 'nonexistent',
          safety: 'mutate',
        }),
      ).rejects.toThrow('not found');
    });
  });

  // -----------------------------------------------------------------------
  // --target all
  // -----------------------------------------------------------------------

  describe('--target all', () => {
    it('returns all sessions', async () => {
      const sess1 = mockSessionInfo({ sessionId: 'a' });
      const sess2 = mockSessionInfo({ sessionId: 'b' });
      const conn = mockConnection([sess1, sess2]);

      const result = await resolveTargetAsync(conn, {
        target: 'all',
        safety: 'read',
      });

      expect(result.sessions).toHaveLength(2);
    });

    it('filters by context when provided', async () => {
      const edit = mockSessionInfo({ sessionId: 'a', context: 'edit' });
      const server = mockSessionInfo({ sessionId: 'b', context: 'server' });
      const conn = mockConnection([edit, server]);

      const result = await resolveTargetAsync(conn, {
        target: 'all',
        context: 'edit',
        safety: 'read',
      });

      expect(result.sessions).toHaveLength(1);
    });

    it('throws when no sessions available', async () => {
      const conn = mockConnection([]);

      await expect(
        resolveTargetAsync(conn, {
          target: 'all',
          safety: 'read',
        }),
      ).rejects.toThrow('No sessions connected');
    });
  });

  // -----------------------------------------------------------------------
  // Auto-resolve (no --target)
  // -----------------------------------------------------------------------

  describe('auto-resolve', () => {
    it('auto-selects when exactly one session', async () => {
      const sess = mockSessionInfo({ sessionId: 'only-one' });
      const conn = mockConnection([sess]);

      const result = await resolveTargetAsync(conn, {
        safety: 'mutate',
      });

      expect(result.sessions).toHaveLength(1);
    });

    it('throws TargetRequiredError for mutate with multiple sessions', async () => {
      const sess1 = mockSessionInfo({ sessionId: 'a' });
      const sess2 = mockSessionInfo({ sessionId: 'b' });
      const conn = mockConnection([sess1, sess2]);

      await expect(
        resolveTargetAsync(conn, { safety: 'mutate' }),
      ).rejects.toThrow(TargetRequiredError);
    });

    it('aggregates all sessions for read safety on CLI', async () => {
      const sess1 = mockSessionInfo({ sessionId: 'a' });
      const sess2 = mockSessionInfo({ sessionId: 'b' });
      const conn = mockConnection([sess1, sess2]);

      const result = await resolveTargetAsync(conn, {
        safety: 'read',
        isMcp: false,
      });

      expect(result.sessions).toHaveLength(2);
    });

    it('throws when no sessions available', async () => {
      const conn = mockConnection([]);

      await expect(
        resolveTargetAsync(conn, { safety: 'read' }),
      ).rejects.toThrow('No sessions connected');
    });
  });

  // -----------------------------------------------------------------------
  // MCP behavior
  // -----------------------------------------------------------------------

  describe('MCP targeting', () => {
    it('throws TargetRequiredError when multiple sessions and isMcp', async () => {
      const sess1 = mockSessionInfo({ sessionId: 'a' });
      const sess2 = mockSessionInfo({ sessionId: 'b' });
      const conn = mockConnection([sess1, sess2]);

      await expect(
        resolveTargetAsync(conn, {
          safety: 'read',
          isMcp: true,
        }),
      ).rejects.toThrow(TargetRequiredError);
    });

    it('auto-selects single session even in MCP mode', async () => {
      const sess = mockSessionInfo({ sessionId: 'only' });
      const conn = mockConnection([sess]);

      const result = await resolveTargetAsync(conn, {
        safety: 'read',
        isMcp: true,
      });

      expect(result.sessions).toHaveLength(1);
    });
  });
});

// ---------------------------------------------------------------------------
// TargetRequiredError
// ---------------------------------------------------------------------------

describe('TargetRequiredError', () => {
  it('includes session listing in message', () => {
    const sessions = [
      mockSessionInfo({ sessionId: 'a', placeName: 'Place A' }),
      mockSessionInfo({ sessionId: 'b', placeName: 'Place B' }),
    ];

    const err = new TargetRequiredError(sessions);

    expect(err.message).toContain('Multiple sessions');
    expect(err.message).toContain('a');
    expect(err.message).toContain('b');
  });

  it('provides structured error payload', () => {
    const sessions = [mockSessionInfo({ sessionId: 'a' })];
    const err = new TargetRequiredError(sessions);

    const structured = err.toStructuredError();
    expect(structured.error).toBe('multiple_sessions');
    expect(structured.hint).toContain('--target');
    expect(structured.sessions).toHaveLength(1);
  });

  it('has correct name', () => {
    const err = new TargetRequiredError([]);
    expect(err.name).toBe('TargetRequiredError');
  });
});
