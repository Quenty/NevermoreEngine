/**
 * Unit tests for the info (state) command handler.
 */

import { describe, it, expect, vi } from 'vitest';

vi.mock('../../../process/studio-process-closer.js', async (importOriginal) => {
  const actual = await importOriginal<
    typeof import('../../../process/studio-process-closer.js')
  >();
  return {
    ...actual,
    listStudioProcessesAsync: vi.fn(async () => [
      { pid: 42, windowTitle: 'C:/places/TestPlace - Roblox Studio' },
    ]),
  };
});

vi.mock('../../../process/studio-window-state.js', () => ({
  tryGetStudioWindowStateAsync: vi.fn(async () => ({
    focused: true,
    minimized: false,
  })),
}));

vi.mock('../../../plugin/plugin-build-version.js', () => ({
  getPluginBuildVersionAsync: async () => 'abc123',
}));

import {
  describePlaytest,
  formatStateText,
  queryStateHandlerAsync,
} from './info.js';

function sessionInfo(
  sessionId: string,
  context: 'edit' | 'server' | 'client',
  overrides: Record<string, unknown> = {}
) {
  return {
    sessionId,
    instanceId: 'test-place-3f9a',
    context,
    origin: 'user',
    placeName: 'TestPlace',
    pluginVersion: 'abc123',
    connectedAt: new Date('2026-10-27T18:00:00Z'),
    ...overrides,
  } as any;
}

function createMockSession(
  stateResult: Record<string, unknown>,
  infoOverrides: Record<string, unknown> = {}
) {
  return {
    info: sessionInfo('test-place-3f9a-edit', 'edit', infoOverrides),
    queryStateAsync: vi.fn().mockResolvedValue({
      state: 'Edit',
      placeId: 12345,
      placeName: 'TestPlace',
      gameId: 67890,
      ...stateResult,
    }),
  } as any;
}

function createConnection(sessions: any[]) {
  return { listSessions: () => sessions } as any;
}

describe('queryStateHandlerAsync', () => {
  it('reports the session, place and run mode', async () => {
    const session = createMockSession({ studioVersion: '0.744.0.7440803' });

    const result = await queryStateHandlerAsync(session);

    expect(result).toMatchObject({
      sessionId: 'test-place-3f9a-edit',
      instanceId: 'test-place-3f9a',
      context: 'edit',
      origin: 'user',
      state: 'Edit',
      placeId: 12345,
      placeName: 'TestPlace',
      gameId: 67890,
      studioVersion: '0.744.0.7440803',
      connectedAt: '2026-10-27T18:00:00.000Z',
    });
    expect(result.summary).toBe('Mode: Edit, Place: TestPlace (12345)');
  });

  it('compares the plugin version with the one the CLI installs', async () => {
    const current = await queryStateHandlerAsync(createMockSession({}));
    const stale = await queryStateHandlerAsync(
      createMockSession({}, { pluginVersion: 'old999' })
    );

    expect(current.plugin).toEqual({
      version: 'abc123',
      expectedVersion: 'abc123',
      upToDate: true,
    });
    expect(stale.plugin.upToDate).toBe(false);
    expect(formatStateText(stale)).toContain(
      "out of date, expected abc123; run 'studio-bridge plugin install'"
    );
  });

  it("reports the playtest running in the session's Studio", async () => {
    const session = createMockSession({});
    const connection = createConnection([
      session.info,
      sessionInfo('test-place-3f9a-server', 'server'),
      sessionInfo('test-place-3f9a-client', 'client', {
        playerName: 'Player1',
      }),
    ]);

    const result = await queryStateHandlerAsync(session, connection);

    expect(result.playtest).toEqual({
      mode: 'play',
      playerCount: undefined,
      sessions: [
        {
          sessionId: 'test-place-3f9a-server',
          context: 'server',
          playerName: undefined,
        },
        {
          sessionId: 'test-place-3f9a-client',
          context: 'client',
          playerName: 'Player1',
        },
      ],
    });
    expect(formatStateText(result)).toContain(
      'Playtest: running (play mode): test-place-3f9a-server, test-place-3f9a-client'
    );
  });

  it("finds a playtest's window by its DataModel's name, not the edit window", async () => {
    const session = createMockSession(
      { state: 'Server', placeName: 'TestPlace' },
      { sessionId: 'test-place-3f9a-server', context: 'server' }
    );
    const connection = createConnection([
      sessionInfo('test-place-3f9a-edit', 'edit'),
      session.info,
      sessionInfo('test-place-3f9a-client-player1', 'client'),
      sessionInfo('test-place-3f9a-client-player2', 'client'),
    ]);

    const result = await queryStateHandlerAsync(session, connection);

    expect(result.window?.pid).toBe(42);

    session.queryStateAsync.mockResolvedValue({
      state: 'Server',
      placeId: 0,
      placeName: 'Server',
      gameId: 0,
    });
    const unmatched = await queryStateHandlerAsync(session, connection);
    expect(unmatched.window).toBeUndefined();
  });

  it('propagates errors from session', async () => {
    const session = createMockSession({});
    session.queryStateAsync.mockRejectedValue(new Error('Connection lost'));

    await expect(queryStateHandlerAsync(session)).rejects.toThrow(
      'Connection lost'
    );
  });

  it('reports the window showing the place', async () => {
    const result = await queryStateHandlerAsync(createMockSession({}));

    expect(result.window).toEqual({ pid: 42, focused: true, minimized: false });
    expect(formatStateText(result)).toContain(
      'Window:   pid 42, open, focused'
    );
  });

  it('leaves the window out when no window shows the place', async () => {
    const result = await queryStateHandlerAsync(
      createMockSession({ placeName: 'Elsewhere' })
    );

    expect(result.window).toBeUndefined();
  });
});

describe('describePlaytest', () => {
  it('is absent without playtest sessions', () => {
    expect(
      describePlaytest(
        [sessionInfo('test-place-3f9a-edit', 'edit')],
        'test-place-3f9a'
      )
    ).toBeUndefined();
  });

  it('reports run mode when only the server connected', () => {
    expect(
      describePlaytest(
        [sessionInfo('test-place-3f9a-server', 'server')],
        'test-place-3f9a'
      )?.mode
    ).toBe('run');
  });

  it('counts the players of a multiplayer test', () => {
    const playtest = describePlaytest(
      [
        sessionInfo('test-place-3f9a-server', 'server'),
        sessionInfo('test-place-3f9a-client-player1', 'client'),
        sessionInfo('test-place-3f9a-client-player2', 'client'),
        sessionInfo('other-1a2b-server', 'server', { instanceId: 'other' }),
      ],
      'test-place-3f9a'
    );

    expect(playtest?.playerCount).toBe(2);
    expect(playtest?.sessions).toHaveLength(3);
  });
});
