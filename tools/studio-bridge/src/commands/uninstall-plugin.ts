/**
 * Handler for the `uninstall-plugin` command. Removes the persistent
 * Studio Bridge plugin from Studio's plugins folder.
 */

import { isPersistentPluginInstalled } from '../plugin/plugin-discovery.js';
import { uninstallPersistentPluginAsync } from '../plugin/persistent-plugin-installer.js';
import { getPersistentPluginPath } from '../plugin/plugin-discovery.js';

export interface UninstallPluginResult {
  summary: string;
}

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
