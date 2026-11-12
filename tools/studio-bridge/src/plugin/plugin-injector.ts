/**
 * Handles building and injecting the Studio plugin .rbxm file into Roblox
 * Studio's plugins folder via rojo, and cleaning it up afterwards.
 */

import { BuildContext } from '@quenty/nevermore-template-helpers/build';
import { findPluginsFolder } from '../process/studio-process-manager.js';
import { getPluginBuildVersionAsync } from './plugin-build-version.js';
import { buildPluginAsync } from './plugin-builder.js';

export interface InjectPluginOptions {
  port: number;
  sessionId: string;
}

export interface InjectedPlugin {
  /** Absolute path to the written .rbxm file */
  pluginPath: string;
  /** Remove the plugin file (idempotent) */
  cleanupAsync: () => Promise<void>;
}

/**
 * Build and install the plugin .rbxm into Studio's plugins folder using rojo.
 */
export async function injectPluginAsync(
  options: InjectPluginOptions
): Promise<InjectedPlugin> {
  const { port, sessionId } = options;

  const buildContext = await BuildContext.createAsync({
    prefix: 'studio-bridge-plugin-',
  });

  try {
    const pluginPath = await buildPluginAsync(
      buildContext,
      {
        PORT: String(port),
        SESSION_ID: sessionId,
        EPHEMERAL: 'true',
        PLUGIN_VERSION: await getPluginBuildVersionAsync(),
      },
      {
        plugin: `studio-bridge-${sessionId}.rbxm`,
        pluginsFolder: findPluginsFolder(),
      }
    );

    return {
      pluginPath: pluginPath!,
      cleanupAsync: () => buildContext.cleanupAsync(),
    };
  } catch (err) {
    await buildContext.cleanupAsync();
    throw err;
  }
}
