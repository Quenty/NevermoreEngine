/**
 * Handles building and injecting the Studio plugin .rbxm file into Roblox
 * Studio's plugins folder via rojo, and cleaning it up afterwards.
 */

import {
  BuildContext,
  TemplateHelper,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import { findPluginsFolder } from '../process/studio-process-manager.js';

const templateDir = resolveTemplatePath(
  import.meta.url,
  'studio-bridge-plugin'
);

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
    await TemplateHelper.createDirectoryContentsAsync(
      templateDir,
      buildContext.buildDir,
      { PORT: String(port), SESSION_ID: sessionId, EPHEMERAL: 'true' },
      false
    );

    const pluginFileName = `studio-bridge-${sessionId}.rbxm`;
    const pluginPath = await buildContext.rojoBuildAsync({
      projectPath: buildContext.resolvePath('default.project.json'),
      plugin: pluginFileName,
      pluginsFolder: findPluginsFolder(),
    });

    return {
      pluginPath: pluginPath!,
      cleanupAsync: () => buildContext.cleanupAsync(),
    };
  } catch (err) {
    await buildContext.cleanupAsync();
    throw err;
  }
}
