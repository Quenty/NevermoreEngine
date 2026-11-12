import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../../plugin/plugin-build-version.js', () => ({
  getPluginBuildVersionAsync: async () => 'current',
}));

const settings = vi.hoisted(() => ({
  loadUserPluginsOnPlaytest: undefined as boolean | undefined,
}));
vi.mock('../../process/studio-settings.js', () => ({
  tryReadLoadUserPluginsOnPlaytestAsync: async () =>
    settings.loadUserPluginsOnPlaytest,
}));

vi.mock('../../plugin/playtest-bridge.js', () => ({
  buildPlaytestBridgeAsync: async (
    scripts?: string[],
    options?: { withClient?: boolean }
  ) => ({
    precompiled: scripts ?? [],
    ...(options?.withClient ? { client: true } : {}),
  }),
}));

import { ContextNotFoundError } from '../../bridge/index.js';
import {
  explainMissingPlaytestContextAsync,
  resolvePlaytestServerSessionAsync,
  startPlaytestAsync,
} from './playtest-sessions.js';

beforeEach(() => {
  settings.loadUserPluginsOnPlaytest = undefined;
});

function createEditSession(pluginVersion: string) {
  return {
    context: 'edit',
    info: {
      sessionId: 'place-1a2b-edit',
      placeName: 'place.rbxl',
      pluginVersion,
    },
    runPlaytestAsync: vi.fn(),
  } as any;
}

describe('startPlaytestAsync multiplayer checks', () => {
  it('refuses a player count that is not a whole number of at least 1', async () => {
    for (const players of [0, 2.5, -1]) {
      const editSession = createEditSession('current');
      await expect(
        startPlaytestAsync({} as any, editSession, 'play', players)
      ).rejects.toThrow(`--players ${players} is out of range.`);
      expect(editSession.runPlaytestAsync).not.toHaveBeenCalled();
    }
  });

  it('refuses run mode', async () => {
    await expect(
      startPlaytestAsync({} as any, createEditSession('current'), 'run', 2)
    ).rejects.toThrow("A multiplayer test can't run in run mode.");
  });

  it('refuses a Studio with an older plugin before starting anything', async () => {
    const editSession = createEditSession('old');

    await expect(
      startPlaytestAsync({} as any, editSession, 'play', 2)
    ).rejects.toThrow("'place.rbxl' is out of date");
    expect(editSession.runPlaytestAsync).not.toHaveBeenCalled();
  });
});

describe('with "Load user plugins on playtest" off', () => {
  it('does not blame the setting for a missing server session, which is planted', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const connection = { listSessions: () => [] } as any;

    await expect(
      resolvePlaytestServerSessionAsync(connection)
    ).rejects.toMatchObject({
      message: 'No playtest is running.',
      fix: "Start one with 'studio-bridge playtest start'.",
    });
  });

  it("ignores this machine's setting when Studio is remote", async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const connection = { listSessions: () => [], isRemote: true } as any;

    await expect(
      resolvePlaytestServerSessionAsync(connection)
    ).rejects.toMatchObject({
      message: 'No playtest is running.',
      fix: "Start one with 'studio-bridge playtest start'.",
    });
  });
});

describe('explainMissingPlaytestContextAsync', () => {
  const connection = {
    listSessions: () => [
      { instanceId: 'inst-1', placeName: 'place.rbxl', context: 'edit' },
    ],
  } as any;

  it('says no playtest is running when the setting is on', async () => {
    settings.loadUserPluginsOnPlaytest = true;
    const err = await explainMissingPlaytestContextAsync(
      connection,
      new ContextNotFoundError('server', 'inst-1', ['edit'])
    );

    expect(err).toMatchObject({
      code: 'NO_PLAYTEST',
      message:
        "No playtest of 'place.rbxl' is running, so there is no server session.",
      fix: "Start one with 'studio-bridge playtest start'.",
    });
  });

  it('names the setting when it is off', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const err = await explainMissingPlaytestContextAsync(
      connection,
      new ContextNotFoundError('client', 'inst-1', ['edit'])
    );

    expect((err as Error).message).toBe(
      `No playtest client of 'place.rbxl' is connected, since Studio's "Load user plugins on playtest" setting is off.`
    );
  });

  it('points a client request at play mode when a run-mode playtest is running', async () => {
    const err = await explainMissingPlaytestContextAsync(
      connection,
      new ContextNotFoundError('client', 'inst-1', ['edit', 'server'])
    );

    expect((err as Error).message).toContain('runs in Run mode');
  });

  it('passes other errors through', async () => {
    const original = new ContextNotFoundError('edit', 'inst-1', ['server']);
    expect(await explainMissingPlaytestContextAsync(connection, original)).toBe(
      original
    );
  });
});

describe('planting the server session', () => {
  function createConnection() {
    return {
      port: 38741,
      isRemote: false,
      listSessions: () => [],
      getSession: () => undefined,
      on: vi.fn(),
      off: vi.fn(),
    } as any;
  }

  // The start fails at once, so the test sees what it was asked to start
  function createFailingEditSession(pluginVersion: string) {
    const editSession = createEditSession(pluginVersion);
    editSession.runPlaytestAsync.mockResolvedValue({
      playtestId: 'p',
      success: false,
      error: 'refused',
    });
    return editSession;
  }

  it('plants a bridge with the scripts to run when the setting is off', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const editSession = createFailingEditSession('current');

    await expect(
      startPlaytestAsync(createConnection(), editSession, 'run', undefined, {
        scripts: ['return 1'],
      })
    ).rejects.toThrow("Studio didn't start the playtest: refused.");

    const bridge = editSession.runPlaytestAsync.mock.calls[0][5];
    expect(bridge.precompiled).toEqual(['return 1']);
  });

  it('plants a client bridge too for a play mode playtest when the setting is off', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const editSession = createFailingEditSession('current');

    await expect(
      startPlaytestAsync(createConnection(), editSession, 'play')
    ).rejects.toThrow("Studio didn't start the playtest: refused.");

    expect(editSession.runPlaytestAsync.mock.calls[0][5].client).toBe(true);
  });

  it('plants no client bridge in run mode, or when the setting is unknown', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const runMode = createFailingEditSession('current');
    await expect(
      startPlaytestAsync(createConnection(), runMode, 'run')
    ).rejects.toThrow('refused');
    expect(runMode.runPlaytestAsync.mock.calls[0][5].client).toBeUndefined();

    settings.loadUserPluginsOnPlaytest = undefined;
    const unknown = createFailingEditSession('current');
    await expect(
      startPlaytestAsync(createConnection(), unknown, 'play')
    ).rejects.toThrow('refused');
    expect(unknown.runPlaytestAsync.mock.calls[0][5].client).toBeUndefined();
  });

  it('plants a bridge when the setting is unknown', async () => {
    const editSession = createFailingEditSession('current');

    await expect(
      startPlaytestAsync(createConnection(), editSession, 'run')
    ).rejects.toThrow('refused');

    expect(editSession.runPlaytestAsync.mock.calls[0][5]).toBeDefined();
  });

  it('leaves the server to the plugin when the setting is on', async () => {
    settings.loadUserPluginsOnPlaytest = true;
    const editSession = createFailingEditSession('current');

    await expect(
      startPlaytestAsync(createConnection(), editSession, 'run')
    ).rejects.toThrow('refused');

    expect(editSession.runPlaytestAsync.mock.calls[0][5]).toBeUndefined();
  });

  it('needs the current plugin to plant a copy of it', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const editSession = createFailingEditSession('old');

    await expect(
      startPlaytestAsync(createConnection(), editSession, 'run')
    ).rejects.toThrow("'place.rbxl' is out of date");
    expect(editSession.runPlaytestAsync).not.toHaveBeenCalled();
  });

  it('needs the current plugin when plugin sessions will connect', async () => {
    settings.loadUserPluginsOnPlaytest = true;
    const editSession = createFailingEditSession('old');

    await expect(
      startPlaytestAsync(createConnection(), editSession, 'run')
    ).rejects.toThrow("'place.rbxl' is out of date");
    expect(editSession.runPlaytestAsync).not.toHaveBeenCalled();
  });
});
