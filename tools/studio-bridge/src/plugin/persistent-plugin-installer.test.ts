/**
 * Unit tests for the persistent plugin installer.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';

// Use vi.hoisted to declare mock functions that will be available in vi.mock factories
const {
  mockIsPersistentPluginInstalled,
  mockGetPersistentPluginPath,
  mockRojoBuildAsync,
  mockCleanupAsync,
  mockResolvePath,
  mockCreateDirectoryContentsAsync,
  mockUnlink,
  mockRm,
} = vi.hoisted(() => ({
  mockIsPersistentPluginInstalled: vi.fn(() => true),
  mockGetPersistentPluginPath: vi.fn(
    () => '/mock/plugins/folder/StudioBridgePersistentPlugin.rbxm',
  ),
  mockRojoBuildAsync: vi.fn().mockResolvedValue(
    '/mock/plugins/folder/StudioBridgePersistentPlugin.rbxm',
  ),
  mockCleanupAsync: vi.fn().mockResolvedValue(undefined),
  mockResolvePath: vi.fn((rel: string) => `/tmp/mock-build-dir/${rel}`),
  mockCreateDirectoryContentsAsync: vi.fn().mockResolvedValue(undefined),
  mockUnlink: vi.fn().mockResolvedValue(undefined),
  mockRm: vi.fn().mockResolvedValue(undefined),
}));

vi.mock('../process/studio-process-manager.js', () => ({
  findPluginsFolder: vi.fn(() => '/mock/plugins/folder'),
}));

vi.mock('./plugin-discovery.js', () => ({
  getPersistentPluginPath: mockGetPersistentPluginPath,
  isPersistentPluginInstalled: mockIsPersistentPluginInstalled,
}));

vi.mock('@quenty/nevermore-template-helpers', () => ({
  BuildContext: {
    createAsync: vi.fn().mockResolvedValue({
      buildDir: '/tmp/mock-build-dir',
      resolvePath: mockResolvePath,
      rojoBuildAsync: mockRojoBuildAsync,
      cleanupAsync: mockCleanupAsync,
    }),
  },
  TemplateHelper: {
    createDirectoryContentsAsync: mockCreateDirectoryContentsAsync,
  },
  resolveTemplatePath: vi.fn(() => '/mock/templates/studio-bridge-plugin'),
}));

vi.mock('fs/promises', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs/promises')>();
  return {
    ...actual,
    unlink: mockUnlink,
    rm: mockRm,
  };
});

import { installPersistentPluginAsync, uninstallPersistentPluginAsync } from './persistent-plugin-installer.js';

describe('persistent-plugin-installer', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Reset defaults
    mockIsPersistentPluginInstalled.mockReturnValue(true);
    mockRojoBuildAsync.mockResolvedValue(
      '/mock/plugins/folder/StudioBridgePersistentPlugin.rbxm',
    );
    mockCreateDirectoryContentsAsync.mockResolvedValue(undefined);
    mockCleanupAsync.mockResolvedValue(undefined);
    mockUnlink.mockResolvedValue(undefined);
    mockRm.mockResolvedValue(undefined);
  });

  describe('installPersistentPluginAsync', () => {
    it('builds plugin from template and returns installed path', async () => {
      const result = await installPersistentPluginAsync();

      expect(result).toBe(
        '/mock/plugins/folder/StudioBridgePersistentPlugin.rbxm',
      );
      expect(mockCreateDirectoryContentsAsync).toHaveBeenCalled();
      expect(mockRojoBuildAsync).toHaveBeenCalled();
    });

    it('cleans up build context on error', async () => {
      mockCreateDirectoryContentsAsync.mockRejectedValueOnce(
        new Error('template error'),
      );

      await expect(installPersistentPluginAsync()).rejects.toThrow('template error');
      expect(mockCleanupAsync).toHaveBeenCalled();
    });
  });

  describe('uninstallPersistentPluginAsync', () => {
    it('removes the plugin file when installed', async () => {
      mockIsPersistentPluginInstalled.mockReturnValue(true);

      await uninstallPersistentPluginAsync();

      expect(mockUnlink).toHaveBeenCalledWith(
        '/mock/plugins/folder/StudioBridgePersistentPlugin.rbxm',
      );
    });

    it('throws when the plugin is not installed', async () => {
      mockIsPersistentPluginInstalled.mockReturnValue(false);

      await expect(uninstallPersistentPluginAsync()).rejects.toThrow(
        'Persistent plugin is not installed',
      );
    });
  });
});
