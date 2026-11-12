/**
 * Unit tests for the persistent plugin installer.
 */

import * as path from 'path';
import { describe, it, expect, vi, beforeEach } from 'vitest';

// The installer joins paths via node's `path.join`, which uses the host
// separator. Compute expectations the same way so these assertions work on
// both POSIX hosts and Windows.
const PLUGINS_FOLDER = '/mock/plugins/folder';
const PLUGIN_FILENAME = 'StudioBridgePersistentPlugin.rbxm';
const EXPECTED_PLUGIN_PATH = path.join(PLUGINS_FOLDER, PLUGIN_FILENAME);
const STAGING_PREFIX = path.join(PLUGINS_FOLDER, `.${PLUGIN_FILENAME}.tmp-`);
const escapeRegex = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const STAGING_REGEX = new RegExp(`^${escapeRegex(STAGING_PREFIX)}`);

const {
  mockGetPersistentPluginPath,
  mockBuildPluginAsync,
  mockCleanupAsync,
  mockResolvePath,
  mockMkdir,
  mockCopyFile,
  mockRename,
  mockUnlink,
} = vi.hoisted(() => ({
  mockGetPersistentPluginPath: vi.fn(
    () => '/mock/plugins/folder/StudioBridgePersistentPlugin.rbxm'
  ),
  mockBuildPluginAsync: vi.fn().mockResolvedValue(undefined),
  mockCleanupAsync: vi.fn().mockResolvedValue(undefined),
  mockResolvePath: vi.fn((rel: string) => `/tmp/mock-build-dir/${rel}`),
  mockMkdir: vi.fn().mockResolvedValue(undefined),
  mockCopyFile: vi.fn().mockResolvedValue(undefined),
  mockRename: vi.fn().mockResolvedValue(undefined),
  mockUnlink: vi.fn().mockResolvedValue(undefined),
}));

vi.mock('../process/studio-process-manager.js', () => ({
  findPluginsFolder: vi.fn(() => '/mock/plugins/folder'),
}));

vi.mock('./plugin-build-version.js', () => ({
  getPluginBuildVersionAsync: vi.fn().mockResolvedValue('abc123'),
}));

vi.mock('./plugin-builder.js', () => ({
  buildPluginAsync: mockBuildPluginAsync,
}));

vi.mock('./plugin-discovery.js', () => ({
  getPersistentPluginPath: mockGetPersistentPluginPath,
}));

vi.mock('@quenty/nevermore-template-helpers/build', () => ({
  BuildContext: {
    createAsync: vi.fn().mockResolvedValue({
      buildDir: '/tmp/mock-build-dir',
      resolvePath: mockResolvePath,
      cleanupAsync: mockCleanupAsync,
    }),
  },
}));
vi.mock('@quenty/nevermore-template-helpers/resolve-template-path', () => ({
  resolvePackagePath: vi.fn(() => '/mock/plugins/studio-bridge-plugin'),
}));

vi.mock('fs/promises', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs/promises')>();
  return {
    ...actual,
    mkdir: mockMkdir,
    copyFile: mockCopyFile,
    rename: mockRename,
    unlink: mockUnlink,
  };
});

import {
  installPersistentPluginAsync,
  uninstallPersistentPluginAsync,
} from './persistent-plugin-installer.js';

describe('persistent-plugin-installer', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockBuildPluginAsync.mockResolvedValue(undefined);
    mockCleanupAsync.mockResolvedValue(undefined);
    mockMkdir.mockResolvedValue(undefined);
    mockCopyFile.mockResolvedValue(undefined);
    mockRename.mockResolvedValue(undefined);
    mockUnlink.mockResolvedValue(undefined);
  });

  describe('installPersistentPluginAsync', () => {
    it('builds plugin and atomically renames into the plugins folder', async () => {
      const result = await installPersistentPluginAsync();

      expect(result).toBe(EXPECTED_PLUGIN_PATH);
      // rojo builds into the temp dir, not the plugins folder.
      expect(mockBuildPluginAsync).toHaveBeenCalledWith(
        expect.anything(),
        { PLUGIN_VERSION: 'abc123' },
        { output: '/tmp/mock-build-dir/StudioBridgePersistentPlugin.rbxm' }
      );
      // copyFile -> rename pattern keeps Studio's polling watcher from
      // observing a partially-written .rbxm.
      expect(mockCopyFile).toHaveBeenCalledTimes(1);
      expect(mockRename).toHaveBeenCalledTimes(1);
      const [renameSrc, renameDest] = mockRename.mock.calls[0];
      expect(renameDest).toBe(EXPECTED_PLUGIN_PATH);
      // Staging file lives in the destination filesystem.
      expect(renameSrc).toMatch(STAGING_REGEX);
    });

    it('cleans up build context on error', async () => {
      mockBuildPluginAsync.mockRejectedValueOnce(new Error('build error'));

      await expect(installPersistentPluginAsync()).rejects.toThrow(
        'build error'
      );
      expect(mockCleanupAsync).toHaveBeenCalled();
    });

    it('cleans up build context on success', async () => {
      await installPersistentPluginAsync();
      expect(mockCleanupAsync).toHaveBeenCalled();
    });

    it('removes staging file when rename fails', async () => {
      mockRename.mockRejectedValueOnce(new Error('rename failed'));

      await expect(installPersistentPluginAsync()).rejects.toThrow(
        'rename failed'
      );
      expect(mockUnlink).toHaveBeenCalledWith(
        expect.stringMatching(STAGING_REGEX)
      );
    });
  });

  describe('uninstallPersistentPluginAsync', () => {
    it('removes the plugin file when installed', async () => {
      await uninstallPersistentPluginAsync();

      expect(mockUnlink).toHaveBeenCalledWith(
        '/mock/plugins/folder/StudioBridgePersistentPlugin.rbxm'
      );
    });

    it('throws a friendly error when the plugin is not installed', async () => {
      const enoent = Object.assign(new Error('ENOENT'), {
        code: 'ENOENT',
      });
      mockUnlink.mockRejectedValueOnce(enoent);

      await expect(uninstallPersistentPluginAsync()).rejects.toThrow(
        "The studio-bridge plugin isn't installed"
      );
    });

    it('propagates non-ENOENT errors', async () => {
      mockUnlink.mockRejectedValueOnce(
        Object.assign(new Error('EACCES'), { code: 'EACCES' })
      );

      await expect(uninstallPersistentPluginAsync()).rejects.toThrow('EACCES');
    });
  });
});
