/**
 * Handles building and injecting the Studio plugin .rbxm file into Roblox
 * Studio's plugins folder via rojo, and cleaning it up afterwards.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import {
  BuildContext,
  rojoBuildAsync,
  substituteTemplate,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import { findPluginsFolder } from '../process/studio-process-manager.js';

const templateDir = resolveTemplatePath(import.meta.url, 'studio-bridge-plugin');

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

  const luaTemplate = await fs.readFile(
    path.join(templateDir, 'plugin-template.server.lua'),
    'utf-8'
  );
  const luaSource = substituteTemplate(luaTemplate, {
    PORT: String(port),
    SESSION_ID: sessionId,
  });

  // Build plugin model in temp dir, output directly to Studio plugins folder
  const ctx = await BuildContext.createAsync({
    mode: 'temp',
    prefix: 'studio-bridge-plugin-',
  });

  try {
    await ctx.writeFileAsync('plugin-template.server.lua', luaSource);

    // Copy the project JSON from the template dir into the temp build dir
    const projectJson = await fs.readFile(
      path.join(templateDir, 'default.project.json'),
      'utf-8'
    );
    const projectPath = await ctx.writeFileAsync(
      'default.project.json',
      projectJson
    );

    const pluginFileName = `studio-bridge-${sessionId}.rbxm`;
    await rojoBuildAsync({ projectPath, plugin: pluginFileName });
    await ctx.cleanupAsync();

    // Return handle for plugins-folder cleanup
    const pluginsFolder = findPluginsFolder();
    const pluginPath = path.join(pluginsFolder, pluginFileName);
    let cleaned = false;

    return {
      pluginPath,
      cleanupAsync: async () => {
        if (cleaned) return;
        cleaned = true;
        try {
          await fs.unlink(pluginPath);
        } catch {
          // File may already be gone
        }
      },
    };
  } catch (err) {
    await ctx.cleanupAsync();
    throw err;
  }
}
