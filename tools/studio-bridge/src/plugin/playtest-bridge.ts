/**
 * Builds the studio-bridge client the edit session plants into a playtest's
 * server, for when Studio does not load user plugins into playtests.
 *
 * The planted client is an ordinary Script, so it can neither `loadstring`
 * nor set a ModuleScript's source. Everything it may run is compiled ahead of
 * time here: each source becomes a ModuleScript returning its function and
 * the source itself, which the client's router looks up by exact text when
 * the bridge pushes an action or sends a script (see PrecompiledSources.lua).
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { resolveTemplatePath } from '@quenty/nevermore-template-helpers';
import { loadActionSourcesAsync } from '../commands/framework/action-loader.js';
import { getPluginBuildVersionAsync } from './plugin-build-version.js';

/** The `bridge` of a `startPlaytest` request. */
export interface PlaytestBridge {
  /** Source of the planted entry Script. */
  entrySource: string;
  /** The plugin's Shared modules, by name. */
  modules: Record<string, string>;
  /** ModuleScript sources compiled ahead of time, see `wrapPrecompiledSource`. */
  precompiled: string[];
}

const templateDir = resolveTemplatePath(
  import.meta.url,
  'studio-bridge-plugin'
);

/**
 * Builds the bridge to plant, able to run every action plus `scripts`, the
 * code a caller will send the playtest's server session.
 */
export async function buildPlaytestBridgeAsync(
  scripts: string[] = []
): Promise<PlaytestBridge> {
  const [entrySource, modules, actions] = await Promise.all([
    fs.readFile(
      path.join(templateDir, 'playtest', 'StudioBridgePlaytest.server.lua'),
      'utf-8'
    ),
    readSharedModulesAsync(),
    loadActionSourcesAsync(),
  ]);

  const sources = [...new Set([...actions.map((a) => a.source), ...scripts])];
  return {
    entrySource,
    modules,
    precompiled: sources.map(wrapPrecompiledSource),
  };
}

async function readSharedModulesAsync(): Promise<Record<string, string>> {
  const sharedDir = path.join(templateDir, 'src', 'Shared');
  const version = await getPluginBuildVersionAsync();

  const modules: Record<string, string> = {};
  for (const fileName of await fs.readdir(sharedDir)) {
    if (!fileName.endsWith('.lua') || fileName.endsWith('.spec.lua')) {
      continue;
    }
    const source = await fs.readFile(path.join(sharedDir, fileName), 'utf-8');
    modules[path.basename(fileName, '.lua')] = source.replaceAll(
      '{{PLUGIN_VERSION}}',
      version
    );
  }
  return modules;
}

/**
 * A ModuleScript source returning `{ fn, source }` for `source`. The function
 * opens on the first line, so line numbers in errors match `source`. The text
 * is a long string led by a character that is cut off again, since a long
 * string drops a leading newline.
 */
export function wrapPrecompiledSource(source: string): string {
  // The string must close at its closer, not inside or straddling `source`
  let level = '';
  while (`${source}]${level}]`.indexOf(`]${level}]`) !== source.length) {
    level += '=';
  }
  return `return { fn = function(...) ${source}\nend, source = string.sub([${level}[x${source}]${level}], 2) }`;
}
