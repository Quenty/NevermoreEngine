/**
 * Unit tests for the list (sessions) command handler.
 */

import { describe, it, expect } from 'vitest';
import type { SessionInfo } from '../../../bridge/index.js';
import { renderResult } from '../../../cli/adapters/cli-command-adapter.js';
import {
  formatSessionsTable,
  listCommand,
  listSessionsHandlerAsync,
} from './list.js';
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
    expect(result.summary).toContain('No Studio is connected');
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
    expect(result.summary).toBe('2 sessions connected.');
  });

  it('returns single session with correct summary', async () => {
    const sessions = [createSessionInfo({ sessionId: 'only-one' })];
    const conn = createMockConnection(sessions);
    const result = await listSessionsHandlerAsync(conn);

    expect(result.sessions).toHaveLength(1);
    expect(result.summary).toBe('1 session connected.');
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

describe('listSessionsHandlerAsync with Studio processes and MCP', () => {
  const now = Date.parse('2026-11-05T00:30:00Z');
  const snapshot = (
    overrides: Partial<StudioMcpSnapshot> = {}
  ): StudioMcpSnapshot => ({
    status: 'ok',
    studios: [],
    checkedAt: now,
    latencyMs: 640,
    ...overrides,
  });
  const processes = [
    {
      pid: 70,
      windowTitle: 'Place1 - Roblox Studio',
      startedAt: now - 300_000,
    },
    {
      pid: 80,
      windowTitle: 'Place1 - Roblox Studio',
      startedAt: now - 290_000,
    },
  ];

  it('says no Studio is open, and how long it waited', async () => {
    const result = await listSessionsHandlerAsync(
      createMockConnection([]),
      {},
      { listProcessesAsync: async () => [], elapsedSec: () => 12.34 }
    );

    expect(result.summary).toBe(
      "Roblox Studio isn't open (12.3s). Run 'studio-bridge process launch' to open it."
    );
  });

  it('says Studio is open without the plugin, rather than that nothing is', async () => {
    const result = await listSessionsHandlerAsync(
      createMockConnection([]),
      {},
      { listProcessesAsync: async () => processes, elapsedSec: () => 5 }
    );

    expect(result.summary).toContain(
      "2 Studio processes open, but the studio-bridge plugin hasn't connected (5.0s)"
    );
  });

  it('lists each Studio with its plugin session, MCP id and where it was launched', async () => {
    const sessions = [
      createSessionInfo({ sessionId: 'a-edit', instanceId: 'a' }),
    ];

    const result = await listSessionsHandlerAsync(
      createMockConnection(sessions),
      {},
      {
        listProcessesAsync: async () => processes,
        resolveSessionPidsAsync: async () => new Map([['a', 70]]),
        readLaunchesAsync: async () => [
          {
            pid: 70,
            cwd: 'C:gameshub',
            opened: 'a new Baseplate',
            launchedAt: now - 301_000,
          },
        ],
        mcpSnapshotAsync: async () =>
          snapshot({
            studios: [
              {
                studioId: 'aaaaaaaa-1',
                placeName: 'Place1',
                pid: 70,
                instanceId: 'a',
              },
              { studioId: 'bbbbbbbb-2', placeName: 'Place1', pid: 80 },
            ],
          }),
      }
    );

    expect(result.sessions[0].pid).toBe(70);
    expect(result.studios).toEqual([
      expect.objectContaining({
        pid: 70,
        instanceId: 'a',
        mcpStudioId: 'aaaaaaaa-1',
        launch: expect.objectContaining({ cwd: 'C:gameshub' }),
      }),
      expect.objectContaining({ pid: 80, mcpStudioId: 'bbbbbbbb-2' }),
    ]);
    const text = formatSessionsTable(result, now);
    expect(text).toContain('a new Baseplate from C:gameshub');
    expect(text).toContain('not by studio-bridge');
    expect(text).toContain('5m');
  });

  it('still lists sessions and Studios when MCP is unavailable, and says why', async () => {
    const result = await listSessionsHandlerAsync(
      createMockConnection([createSessionInfo({ sessionId: 's1' })]),
      {},
      {
        listProcessesAsync: async () => processes,
        mcpSnapshotAsync: async () =>
          snapshot({ status: 'timeout', message: 'tools/call timed out' }),
      }
    );

    const text = formatSessionsTable(result, now);
    expect(text).toContain('s1');
    expect(text).toContain('MCP: timeout (tools/call timed out)');
    expect(result.studios).toHaveLength(2);
  });

  it('leaves MCP out when the check gave up or the platform has none', async () => {
    for (const mcpSnapshotAsync of [
      async () => undefined,
      async () => snapshot({ status: 'unsupported' }),
    ]) {
      const result = await listSessionsHandlerAsync(
        createMockConnection([createSessionInfo({ sessionId: 's1' })]),
        {},
        { mcpSnapshotAsync }
      );
      expect(formatSessionsTable(result, now)).not.toContain('MCP');
    }
  });
});

describe('process list --format csv', () => {
  it('writes a row per session, leaving an unknown pid empty', () => {
    const result = {
      sessions: [
        { ...createSessionInfo(), pid: 4242 },
        createSessionInfo({
          sessionId: 'session-2',
          context: 'server',
          state: 'Run',
        }),
      ],
      summary: '',
    };

    expect(renderResult(listCommand, result, 'csv')).toBe(
      [
        'sessionId,context,placeName,state,pid',
        'session-1,edit,TestPlace,Edit,4242',
        'session-2,server,TestPlace,Run,',
        '',
      ].join('\n')
    );
  });
});
