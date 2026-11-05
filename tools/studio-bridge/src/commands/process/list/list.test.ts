/**
 * Unit tests for the list (sessions) command handler.
 */

import { describe, it, expect } from 'vitest';
import type { SessionInfo } from '../../../bridge/index.js';
import { formatSessionsTable, listSessionsHandlerAsync } from './list.js';
import type { StudioMcpSnapshot } from '../../../roblox-mcp/index.js';

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
    findSessions: () => sessions,
    getSession: (id: string) => sessions.find((s) => s.sessionId === id),
  } as any;
}

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

describe('listSessionsHandlerAsync with MCP', () => {
  const snapshot = (
    overrides: Partial<StudioMcpSnapshot> = {}
  ): StudioMcpSnapshot => ({
    status: 'ok',
    studios: [],
    checkedAt: Date.now(),
    latencyMs: 640,
    ...overrides,
  });

  it('lists a Studio only MCP can see, for a plugin that is off', async () => {
    const conn = createMockConnection([]);

    const result = await listSessionsHandlerAsync(
      conn,
      {},
      {
        mcpSnapshotAsync: async () =>
          snapshot({ studios: [{ studioId: 'mcp-1', placeName: 'Hub' }] }),
      }
    );

    expect(result.summary).toContain('without the studio-bridge plugin: Hub');
    expect(result.studiosWithoutPlugin).toEqual([
      { studioId: 'mcp-1', placeName: 'Hub' },
    ]);
    const text = formatSessionsTable(result);
    expect(text).toContain('(no plugin)');
    expect(text).toContain('MCP: ok, 1 Studio(s), answered in 640ms');
  });

  it('marks which plugin sessions MCP can also reach', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 'a-edit', instanceId: 'a' }),
      createSessionInfo({ sessionId: 'b-edit', instanceId: 'b' }),
    ];

    const result = await listSessionsHandlerAsync(
      createMockConnection(sessions),
      {},
      {
        mcpSnapshotAsync: async () =>
          snapshot({
            studios: [
              {
                studioId: 'mcp-1',
                placeName: 'TestPlace',
                sessionId: 'a-edit',
              },
            ],
          }),
      }
    );

    const lines = formatSessionsTable(result).split('\n');
    expect(lines.find((l) => l.includes('a-edit'))).toMatch(/yes\s*$/);
    expect(lines.find((l) => l.includes('b-edit'))).toMatch(/no\s*$/);
  });

  it('still lists plugin sessions when MCP is unavailable, and says why', async () => {
    const result = await listSessionsHandlerAsync(
      createMockConnection([createSessionInfo({ sessionId: 's1' })]),
      {},
      {
        mcpSnapshotAsync: async () =>
          snapshot({ status: 'timeout', message: 'tools/call timed out' }),
      }
    );

    const text = formatSessionsTable(result);
    expect(text).toContain('s1');
    expect(text).toContain('MCP: timeout (tools/call timed out)');
  });

  it('lists plugin sessions alone when the MCP check gave up', async () => {
    const result = await listSessionsHandlerAsync(
      createMockConnection([createSessionInfo({ sessionId: 's1' })]),
      {},
      { mcpSnapshotAsync: async () => undefined }
    );

    expect(result.mcp).toBeUndefined();
    expect(formatSessionsTable(result)).not.toContain('MCP');
  });

  it('hides MCP on a platform it does not run on', async () => {
    const result = await listSessionsHandlerAsync(
      createMockConnection([createSessionInfo({ sessionId: 's1' })]),
      {},
      { mcpSnapshotAsync: async () => snapshot({ status: 'unsupported' }) }
    );

    expect(formatSessionsTable(result)).not.toContain('MCP');
  });
});
