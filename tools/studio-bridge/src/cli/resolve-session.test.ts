/**
 * Unit tests for the CLI session resolution utility.
 */

import { describe, it, expect } from 'vitest';
import type { SessionInfo } from '../bridge/index.js';
import { resolveSessionAsync } from './resolve-session.js';

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

describe('resolveSessionAsync', () => {
  it('returns session when sessionId matches', async () => {
    const session = createSessionInfo({ sessionId: 'abc-123' });
    const conn = createMockConnection([session]);

    const result = await resolveSessionAsync(conn, { sessionId: 'abc-123' });
    expect(result.sessionId).toBe('abc-123');
  });

  it('throws when sessionId does not match', async () => {
    const conn = createMockConnection([createSessionInfo()]);

    await expect(
      resolveSessionAsync(conn, { sessionId: 'nonexistent' }),
    ).rejects.toThrow("Session 'nonexistent' not found.");
  });

  it('returns sole session when no filters and exactly one session', async () => {
    const session = createSessionInfo({ sessionId: 'only-one' });
    const conn = createMockConnection([session]);

    const result = await resolveSessionAsync(conn);
    expect(result.sessionId).toBe('only-one');
  });

  it('throws when no sessions match', async () => {
    const conn = createMockConnection([]);

    await expect(resolveSessionAsync(conn)).rejects.toThrow(
      'No matching sessions found. Is Studio running with the studio-bridge plugin?',
    );
  });

  it('throws descriptive error when multiple sessions match', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 'ses-1', instanceId: 'inst-a' }),
      createSessionInfo({ sessionId: 'ses-2', instanceId: 'inst-b' }),
    ];
    const conn = createMockConnection(sessions);

    await expect(resolveSessionAsync(conn)).rejects.toThrow(
      /Multiple sessions found.*--session.*--instance/s,
    );
  });

  it('filters by instanceId', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 'ses-1', instanceId: 'inst-a' }),
      createSessionInfo({ sessionId: 'ses-2', instanceId: 'inst-b' }),
    ];
    const conn = createMockConnection(sessions);

    const result = await resolveSessionAsync(conn, { instanceId: 'inst-b' });
    expect(result.sessionId).toBe('ses-2');
  });

  it('filters by context', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 'ses-edit', context: 'edit' }),
      createSessionInfo({ sessionId: 'ses-server', context: 'server' }),
    ];
    const conn = createMockConnection(sessions);

    const result = await resolveSessionAsync(conn, { context: 'server' });
    expect(result.sessionId).toBe('ses-server');
  });

  it('combines instanceId and context filters', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 's1', instanceId: 'inst-a', context: 'edit' }),
      createSessionInfo({ sessionId: 's2', instanceId: 'inst-a', context: 'server' }),
      createSessionInfo({ sessionId: 's3', instanceId: 'inst-b', context: 'edit' }),
    ];
    const conn = createMockConnection(sessions);

    const result = await resolveSessionAsync(conn, {
      instanceId: 'inst-a',
      context: 'server',
    });
    expect(result.sessionId).toBe('s2');
  });

  it('throws when filters match zero sessions', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 'ses-1', instanceId: 'inst-a', context: 'edit' }),
    ];
    const conn = createMockConnection(sessions);

    await expect(
      resolveSessionAsync(conn, { context: 'server' }),
    ).rejects.toThrow('No matching sessions found');
  });
});
