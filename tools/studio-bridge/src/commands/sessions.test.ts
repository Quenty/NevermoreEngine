/**
 * Unit tests for the sessions command handler.
 */

import { describe, it, expect } from 'vitest';
import type { SessionInfo } from '../bridge/index.js';
import { listSessionsHandlerAsync } from './sessions.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

function createMockConnection(sessions: SessionInfo[]) {
  return {
    listSessions: () => sessions,
    getSession: (id: string) => sessions.find((s) => s.sessionId === id),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('listSessionsHandlerAsync', () => {
  it('returns empty sessions with helpful message', async () => {
    const conn = createMockConnection([]);
    const result = await listSessionsHandlerAsync(conn);

    expect(result.sessions).toEqual([]);
    expect(result.summary).toContain('No active sessions');
    expect(result.summary).toContain('studio-bridge plugin');
  });

  it('returns sessions with count summary', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 's1' }),
      createSessionInfo({ sessionId: 's2' }),
    ];
    const conn = createMockConnection(sessions);
    const result = await listSessionsHandlerAsync(conn);

    expect(result.sessions).toHaveLength(2);
    expect(result.summary).toBe('2 session(s) connected.');
  });

  it('returns single session with correct summary', async () => {
    const sessions = [createSessionInfo({ sessionId: 'only-one' })];
    const conn = createMockConnection(sessions);
    const result = await listSessionsHandlerAsync(conn);

    expect(result.sessions).toHaveLength(1);
    expect(result.summary).toBe('1 session(s) connected.');
  });

  it('sessions data includes expected fields', async () => {
    const session = createSessionInfo({
      sessionId: 'test-id',
      placeName: 'MyPlace',
      context: 'server',
      state: 'Play',
      origin: 'managed',
    });
    const conn = createMockConnection([session]);
    const result = await listSessionsHandlerAsync(conn);

    const s = result.sessions[0];
    expect(s.sessionId).toBe('test-id');
    expect(s.placeName).toBe('MyPlace');
    expect(s.context).toBe('server');
    expect(s.state).toBe('Play');
    expect(s.origin).toBe('managed');
  });
});
