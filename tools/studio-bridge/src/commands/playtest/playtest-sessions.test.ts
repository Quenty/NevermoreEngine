import { describe, it, expect, vi } from 'vitest';

vi.mock('../../plugin/plugin-build-version.js', () => ({
  getPluginBuildVersionAsync: async () => 'current',
}));

import { startPlaytestAsync } from './playtest-sessions.js';

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
