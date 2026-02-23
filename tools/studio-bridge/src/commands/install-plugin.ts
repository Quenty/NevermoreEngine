/**
 * Handler for the `install-plugin` command. Builds and installs
 * the persistent Studio Bridge plugin into Studio's plugins folder.
 */

import { installPersistentPluginAsync } from '../plugin/persistent-plugin-installer.js';

export interface InstallPluginResult {
  path: string;
  summary: string;
}

/**
 * Install the persistent Studio Bridge plugin.
 */
export async function installPluginHandlerAsync(): Promise<InstallPluginResult> {
  const installedPath = await installPersistentPluginAsync();

  return {
    path: installedPath,
    summary: `Persistent plugin installed to ${installedPath}`,
  };
}
