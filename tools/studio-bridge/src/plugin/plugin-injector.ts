/**
 * Handles writing the Studio plugin .rbxmx file into Roblox Studio's plugins
 * folder and cleaning it up afterwards.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { buildRbxmx } from './rbxmx-builder.js';
import { findPluginsFolder } from '../process/studio-process-manager.js';

const PLUGIN_TEMPLATE_FILENAME = 'plugin-template.lua';

/**
 * Read the Lua plugin template source from the file bundled alongside this
 * module. We resolve relative to import.meta.url so it works regardless of
 * the working directory.
 */
async function readPluginTemplateAsync(): Promise<string> {
  const thisDir = decodeURIComponent(
    path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1'))
  );

  // tsc compiles to dist/src/plugin/, so when running from compiled JS thisDir
  // is dist/src/plugin/. The .lua file lives in src/plugin/ (not copied by tsc).
  // We try:
  //   1. Same directory (works when running source directly via tsx)
  //   2. ../../../src/plugin/ (works when running from dist/src/plugin/)
  const candidates = [
    path.resolve(thisDir, 'template', PLUGIN_TEMPLATE_FILENAME),
    path.resolve(
      thisDir,
      '..',
      '..',
      '..',
      'src',
      'plugin',
      'template',
      PLUGIN_TEMPLATE_FILENAME
    ),
  ];

  for (const candidate of candidates) {
    try {
      return await fs.readFile(candidate, 'utf-8');
    } catch {
      // try next
    }
  }

  throw new Error(
    `Could not find ${PLUGIN_TEMPLATE_FILENAME} in any of:\n${candidates.join('\n')}`
  );
}

export interface InjectPluginOptions {
  port: number;
  sessionId: string;
}

export interface InjectedPlugin {
  /** Absolute path to the written .rbxmx file */
  pluginPath: string;
  /** Remove the plugin file (idempotent) */
  cleanupAsync: () => Promise<void>;
}

/**
 * Substitute template placeholders in the Lua source.
 *
 * Exported for testing.
 */
export function substituteTemplate(
  template: string,
  vars: { port: string; sessionId: string }
): string {
  return template
    .replace(/\{\{PORT\}\}/g, vars.port)
    .replace(/\{\{SESSION_ID\}\}/g, vars.sessionId);
}

/**
 * Escape a Luau string so it can be safely embedded inside a double-quoted
 * Lua string literal. We only need to handle the characters that would break
 * the template substitution — the script content is placed into a variable
 * that is later passed to `loadstring()`, so we use long-bracket quoting in
 * the template to avoid most escaping issues. However, we still need to make
 * sure the script content doesn't contain the closing long bracket.
 *
 * Since the template uses `"{{SCRIPT}}"` as a regular double-quoted string,
 * we need to escape backslashes, double-quotes, and newlines.
 */
export function escapeLuaString(source: string): string {
  return source
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\0/g, '\\0');
}

/**
 * Build and write the plugin .rbxmx into Studio's plugins folder.
 */
export async function injectPluginAsync(
  options: InjectPluginOptions
): Promise<InjectedPlugin> {
  const { port, sessionId } = options;

  const template = await readPluginTemplateAsync();
  const luaSource = substituteTemplate(template, {
    port: String(port),
    sessionId,
  });

  const rbxmx = buildRbxmx({
    name: 'StudioBridgePlugin',
    source: luaSource,
  });

  const pluginsFolder = findPluginsFolder();
  const pluginFileName = `studio-bridge-${sessionId}.rbxmx`;
  const pluginPath = path.join(pluginsFolder, pluginFileName);

  // Ensure the plugins folder exists
  await fs.mkdir(pluginsFolder, { recursive: true });
  await fs.writeFile(pluginPath, rbxmx, 'utf-8');

  let cleaned = false;
  const cleanupAsync = async () => {
    if (cleaned) return;
    cleaned = true;
    try {
      await fs.unlink(pluginPath);
    } catch {
      // File may already be gone
    }
  };

  return { pluginPath, cleanupAsync };
}
