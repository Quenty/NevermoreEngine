/**
 * `plugin install` — install the persistent Studio Bridge plugin.
 */

import { defineCommand } from '../../framework/define-command.js';
import { installPersistentPluginAsync } from '../../../plugin/persistent-plugin-installer.js';

export interface InstallPluginResult {
  path: string;
  summary: string;
}

export async function installPluginHandlerAsync(): Promise<InstallPluginResult> {
  const installedPath = await installPersistentPluginAsync();

  return {
    path: installedPath,
    summary: `Persistent plugin installed to ${installedPath}`,
  };
}

export const installCommand = defineCommand({
  group: 'plugin',
  name: 'install',
  description: 'Install the persistent Studio Bridge plugin',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {},
  handler: async () => installPluginHandlerAsync(),
});
