import { describe, it, expect, afterEach, vi } from 'vitest';

vi.mock('../plugin/plugin-build-version.js', () => ({
  getPluginBuildVersionAsync: vi.fn(async () => 'current'),
}));

import { getPluginBuildVersionAsync } from '../plugin/plugin-build-version.js';
import {
  clearWarnings,
  getWarnings,
  setJsonOutput,
  warnIfPluginStaleAsync,
} from './cli-output-context.js';

describe('cli-output-context', () => {
  afterEach(() => {
    clearWarnings();
    setJsonOutput(false);
    vi.restoreAllMocks();
  });

  it('warns about an outdated plugin without its build hashes', async () => {
    setJsonOutput(true);

    await warnIfPluginStaleAsync([
      { placeName: 'A', pluginVersion: 'current', context: 'edit' },
      { placeName: 'B', pluginVersion: 'old', context: 'edit' },
    ] as any);

    expect(getWarnings()).toEqual([
      "The studio-bridge plugin in 'B' is out of date, so some commands may fail. Run 'studio-bridge plugin install'.",
    ]);
  });

  it('points an outdated playtest plugin at playtest restart', async () => {
    setJsonOutput(true);

    await warnIfPluginStaleAsync([
      { placeName: 'B', pluginVersion: 'old', context: 'server' },
    ] as any);

    expect(getWarnings()).toEqual([
      "The studio-bridge plugin in the playtest of 'B' is out of date, so some commands may fail. Run 'studio-bridge plugin install', then 'studio-bridge playtest restart'.",
    ]);
  });

  it('turns a failed plugin check into a warning instead of rejecting', async () => {
    setJsonOutput(true);
    vi.mocked(getPluginBuildVersionAsync).mockRejectedValueOnce(
      new Error('template missing')
    );

    await expect(
      warnIfPluginStaleAsync([{ pluginVersion: 'old' }] as any)
    ).resolves.toBeUndefined();

    expect(getWarnings()).toEqual([
      "Couldn't check whether the studio-bridge plugin is up to date. Reinstall @quenty/studio-bridge if this keeps happening.",
    ]);
  });
});
