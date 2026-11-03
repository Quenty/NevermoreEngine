import { describe, it, expect, afterEach, vi } from 'vitest';

vi.mock('../plugin/plugin-build-version.js', () => ({
  getPluginBuildVersionAsync: async () => 'current',
}));

import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  addWarning,
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

  it('prints warnings right away in text mode', () => {
    const warn = vi.spyOn(OutputHelper, 'warn').mockImplementation(() => {});

    addWarning('careful');

    expect(warn).toHaveBeenCalledWith('careful');
    expect(getWarnings()).toEqual(['careful']);
  });

  it('only collects warnings in JSON mode', () => {
    const warn = vi.spyOn(OutputHelper, 'warn').mockImplementation(() => {});
    setJsonOutput(true);

    addWarning('careful');
    addWarning('careful');

    expect(warn).not.toHaveBeenCalled();
    expect(getWarnings()).toEqual(['careful']);
  });

  it('warns about plugins built from a different template', async () => {
    setJsonOutput(true);

    await warnIfPluginStaleAsync([
      { sessionId: 'a-edit', placeName: 'A', pluginVersion: 'current' },
      { sessionId: 'b-edit', placeName: 'B', pluginVersion: 'old' },
    ] as any);

    expect(getWarnings()).toEqual([
      expect.stringContaining("'B' (b-edit) is out of date"),
    ]);
  });
});
