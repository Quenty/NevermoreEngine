/**
 * Unit tests for plugin discovery utilities.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as path from 'path';

// Mock dependencies before importing the module under test
vi.mock('../process/studio-process-manager.js', () => ({
  findPluginsFolder: vi.fn(() => '/mock/plugins/folder'),
}));

vi.mock('fs', () => ({
  existsSync: vi.fn(() => false),
}));

import { existsSync } from 'fs';
import { getPersistentPluginPath, isPersistentPluginInstalled } from './plugin-discovery.js';

const mockedExistsSync = vi.mocked(existsSync);

describe('plugin-discovery', () => {
  let originalCI: string | undefined;

  beforeEach(() => {
    vi.clearAllMocks();
    originalCI = process.env.CI;
  });

  afterEach(() => {
    if (originalCI === undefined) {
      delete process.env.CI;
    } else {
      process.env.CI = originalCI;
    }
  });

  describe('getPersistentPluginPath', () => {
    it('returns path combining plugins folder and filename', () => {
      const result = getPersistentPluginPath();
      expect(result).toBe(
        path.join('/mock/plugins/folder', 'StudioBridgePersistentPlugin.rbxm'),
      );
    });
  });

  describe('isPersistentPluginInstalled', () => {
    it('returns true when the plugin file exists', () => {
      mockedExistsSync.mockReturnValue(true);
      expect(isPersistentPluginInstalled()).toBe(true);
    });

    it('returns false when the plugin file does not exist', () => {
      mockedExistsSync.mockReturnValue(false);
      expect(isPersistentPluginInstalled()).toBe(false);
    });

    it('returns false in CI environment regardless of file existence', () => {
      process.env.CI = 'true';
      mockedExistsSync.mockReturnValue(true);
      expect(isPersistentPluginInstalled()).toBe(false);
      // existsSync should not even be called in CI
      expect(mockedExistsSync).not.toHaveBeenCalled();
    });
  });
});
