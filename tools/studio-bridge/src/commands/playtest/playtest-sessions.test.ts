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
      ).rejects.toThrow('--players must be a whole number of at least 1');
      expect(editSession.runPlaytestAsync).not.toHaveBeenCalled();
    }
  });

  it('refuses run mode', async () => {
    await expect(
      startPlaytestAsync({} as any, createEditSession('current'), 'run', 2)
    ).rejects.toThrow('A multiplayer test runs in play mode');
  });

  it('refuses a Studio with an older plugin before starting anything', async () => {
    const editSession = createEditSession('old');

    await expect(
      startPlaytestAsync({} as any, editSession, 'play', 2)
    ).rejects.toThrow("Run 'studio-bridge plugin install' first");
    expect(editSession.runPlaytestAsync).not.toHaveBeenCalled();
  });
});

describe('with "Load user plugins on playtest" off', () => {
  it('refuses to start a playtest whose sessions could never connect', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const editSession = createEditSession('current');

    await expect(
      startPlaytestAsync({} as any, editSession, 'play')
    ).rejects.toThrow(
      `Studio's "Load user plugins on playtest" setting is off`
    );
    expect(editSession.runPlaytestAsync).not.toHaveBeenCalled();
  });

  it('names the setting when no server session is connected', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const connection = { listSessions: () => [] } as any;

    await expect(resolvePlaytestServerSessionAsync(connection)).rejects.toThrow(
      `No playtest is connected. Studio's "Load user plugins on playtest" setting is off`
    );
  });

  it("ignores this machine's setting when Studio is remote", async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const connection = { listSessions: () => [], isRemote: true } as any;

    await expect(resolvePlaytestServerSessionAsync(connection)).rejects.toThrow(
      "No playtest is running. Start one with 'studio-bridge playtest start'."
    );
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

    expect((err as Error).message).toBe(
      "No playtest of 'place.rbxl' is running, so there is no server session. Start one with 'studio-bridge playtest start'."
    );
  });

  it('names the setting when it is off', async () => {
    settings.loadUserPluginsOnPlaytest = false;
    const err = await explainMissingPlaytestContextAsync(
      connection,
      new ContextNotFoundError('client', 'inst-1', ['edit'])
    );

    expect((err as Error).message).toContain(
      `No playtest of 'place.rbxl' is connected. Studio's "Load user plugins on playtest" setting is off`
    );
  });

  it('points a client request at play mode when a run-mode playtest is running', async () => {
    const err = await explainMissingPlaytestContextAsync(
      connection,
      new ContextNotFoundError('client', 'inst-1', ['edit', 'server'])
    );

    expect((err as Error).message).toContain('runs in run mode');
  });

  it('passes other errors through', async () => {
    const original = new ContextNotFoundError('edit', 'inst-1', ['server']);
    expect(await explainMissingPlaytestContextAsync(connection, original)).toBe(
      original
    );
  });
});
