/**
 * `plugin uninstall` — remove the persistent Studio Bridge plugin.
 */

import { defineCommand } from '../../framework/define-command.js';
import {
  getPersistentPluginPath,
  isPersistentPluginInstalled,
} from '../../../plugin/plugin-discovery.js';
import { uninstallPersistentPluginAsync } from '../../../plugin/persistent-plugin-installer.js';

export interface UninstallPluginResult {
  summary: string;
}

export async function uninstallPluginHandlerAsync(): Promise<UninstallPluginResult> {
  const pluginPath = getPersistentPluginPath();

  // Check first for a clean UX message, but rely on uninstallPersistentPluginAsync's
  // ENOENT handling for the authoritative outcome (avoids TOCTOU between this
  // check and the actual unlink).
  if (!isPersistentPluginInstalled()) {
    return {
      summary: 'Persistent plugin is not installed. Nothing to remove.',
    };
  }

  try {
    await uninstallPersistentPluginAsync();
  } catch (err) {
    if (
      err instanceof Error &&
      err.message.startsWith('Persistent plugin is not installed')
    ) {
      return { summary: err.message };
    }
    throw err;
  }

  return {
    summary: `Persistent plugin removed from ${pluginPath}`,
  };
}

export const uninstallCommand = defineCommand({
  group: 'plugin',
  name: 'uninstall',
  description: 'Remove the persistent Studio Bridge plugin',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {},
  handler: async () => uninstallPluginHandlerAsync(),
});
