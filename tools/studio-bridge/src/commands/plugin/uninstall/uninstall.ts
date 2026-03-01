/**
 * `plugin uninstall` — remove the persistent Studio Bridge plugin.
 */

import { defineCommand } from '../../framework/define-command.js';
import { isPersistentPluginInstalled } from '../../../plugin/plugin-discovery.js';
import { uninstallPersistentPluginAsync } from '../../../plugin/persistent-plugin-installer.js';
import { getPersistentPluginPath } from '../../../plugin/plugin-discovery.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface UninstallPluginResult {
  summary: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * Uninstall the persistent Studio Bridge plugin.
 */
export async function uninstallPluginHandlerAsync(): Promise<UninstallPluginResult> {
  if (!isPersistentPluginInstalled()) {
    return {
      summary: 'Persistent plugin is not installed. Nothing to remove.',
    };
  }

  const pluginPath = getPersistentPluginPath();
  await uninstallPersistentPluginAsync();

  return {
    summary: `Persistent plugin removed from ${pluginPath}`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

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
