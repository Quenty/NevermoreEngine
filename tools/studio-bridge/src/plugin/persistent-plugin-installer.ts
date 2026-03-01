/**
 * Builds and installs (or uninstalls) the persistent Studio Bridge plugin
 * into Roblox Studio's plugins folder using rojo.
 */

import * as fs from 'fs/promises';
import {
  BuildContext,
  TemplateHelper,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import { findPluginsFolder } from '../process/studio-process-manager.js';
import { getPersistentPluginPath, isPersistentPluginInstalled } from './plugin-discovery.js';

const templateDir = resolveTemplatePath(
  import.meta.url,
  'studio-bridge-plugin'
);

const PERSISTENT_PLUGIN_FILENAME = 'StudioBridgePersistentPlugin.rbxm';

/**
 * Build the persistent plugin template via rojo and copy the resulting
 * `.rbxm` into the Studio plugins folder.
 *
 * @returns The absolute path to the installed plugin file.
 */
export async function installPersistentPluginAsync(): Promise<string> {
  const buildContext = await BuildContext.createAsync({
    prefix: 'studio-bridge-persistent-plugin-',
  });

  try {
    await TemplateHelper.createDirectoryContentsAsync(
      templateDir,
      buildContext.buildDir,
      {},
      false,
    );

    const pluginsFolder = findPluginsFolder();
    const pluginPath = await buildContext.rojoBuildAsync({
      projectPath: buildContext.resolvePath('default.project.json'),
      plugin: PERSISTENT_PLUGIN_FILENAME,
      pluginsFolder,
    });

    // rojoBuildAsync tracks the file for cleanup, but we want the plugin
    // to persist. Cleanup only removes the temp build directory, not the
    // plugin file, because we return before cleanupAsync is called for
    // tracked files. However, BuildContext.cleanupAsync removes tracked
    // files. We need to avoid that — so we skip cleanupAsync and remove
    // only the build dir manually.
    try {
      await fs.rm(buildContext.buildDir, { recursive: true, force: true });
    } catch {
      // best effort
    }

    return pluginPath!;
  } catch (err) {
    await buildContext.cleanupAsync();
    throw err;
  }
}

/**
 * Remove the persistent plugin file from the Studio plugins folder.
 * Throws if the plugin is not installed.
 */
export async function uninstallPersistentPluginAsync(): Promise<void> {
  if (!isPersistentPluginInstalled()) {
    throw new Error(
      'Persistent plugin is not installed. Nothing to remove.',
    );
  }

  const pluginPath = getPersistentPluginPath();
  await fs.unlink(pluginPath);
}
