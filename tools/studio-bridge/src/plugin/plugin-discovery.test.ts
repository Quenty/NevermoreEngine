/**
 * Unit tests for plugin discovery utilities.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
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
  beforeEach(() => {
    vi.clearAllMocks();
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
  });
});
