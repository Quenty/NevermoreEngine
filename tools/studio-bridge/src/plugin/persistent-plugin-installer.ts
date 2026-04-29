/**
 * Builds and installs (or uninstalls) the persistent Studio Bridge plugin
 * into Roblox Studio's plugins folder using rojo.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import {
  BuildContext,
  TemplateHelper,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import { findPluginsFolder } from '../process/studio-process-manager.js';
import { getPersistentPluginPath } from './plugin-discovery.js';

const templateDir = resolveTemplatePath(
  import.meta.url,
  'studio-bridge-plugin'
);

const PERSISTENT_PLUGIN_FILENAME = 'StudioBridgePersistentPlugin.rbxm';

/**
 * Build the persistent plugin template via rojo and atomically install the
 * resulting `.rbxm` into the Studio plugins folder.
 *
 * The build runs inside the BuildContext's temp dir; the file is then
 * copied to a temp name in the plugins folder and renamed into place so
 * Studio's polling watcher never observes a partially-written .rbxm.
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
      false
    );

    const builtPath = buildContext.resolvePath(PERSISTENT_PLUGIN_FILENAME);
    await buildContext.rojoBuildAsync({
      projectPath: buildContext.resolvePath('default.project.json'),
      output: builtPath,
    });

    const pluginsFolder = findPluginsFolder();
    await fs.mkdir(pluginsFolder, { recursive: true });

    const finalPath = path.join(pluginsFolder, PERSISTENT_PLUGIN_FILENAME);
    // Stage in the destination filesystem so the rename is atomic.
    const stagingPath = path.join(
      pluginsFolder,
      `.${PERSISTENT_PLUGIN_FILENAME}.tmp-${process.pid}`
    );
    await fs.copyFile(builtPath, stagingPath);
    try {
      await fs.rename(stagingPath, finalPath);
    } catch (err) {
      // Best-effort cleanup of the staging file before propagating.
      await fs.unlink(stagingPath).catch(() => {});
      throw err;
    }

    return finalPath;
  } finally {
    await buildContext.cleanupAsync();
  }
}

/**
 * Remove the persistent plugin file from the Studio plugins folder.
 * Throws if the plugin is not installed.
 */
export async function uninstallPersistentPluginAsync(): Promise<void> {
  const pluginPath = getPersistentPluginPath();
  try {
    await fs.unlink(pluginPath);
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') {
      throw new Error('Persistent plugin is not installed. Nothing to remove.');
    }
    throw err;
  }
}
