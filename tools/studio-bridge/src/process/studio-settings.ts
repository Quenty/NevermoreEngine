/**
 * Reads Studio's own settings from the file it saves them to, for settings a
 * plugin can't read.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { findPluginsFolder } from './studio-process-manager.js';

/** The XML name of Studio's "Load user plugins on playtest" setting. */
const LOAD_USER_PLUGINS_ON_PLAYTEST = 'LoadUserPluginsInRunModes';

/**
 * Whether Studio's "Load user plugins on playtest" setting is on. Without it,
 * the plugin doesn't load into a playtest's DataModels, so they never connect
 * to the bridge. Undefined when the setting can't be read, e.g. on macOS,
 * whose settings file isn't located here.
 */
export async function tryReadLoadUserPluginsOnPlaytestAsync(): Promise<
  boolean | undefined
> {
  const settingsPath = findGlobalSettingsPath();
  if (!settingsPath) {
    return undefined;
  }

  let xml: string;
  try {
    xml = await fs.readFile(settingsPath, 'utf8');
  } catch {
    return undefined;
  }
  return parseBoolSetting(xml, LOAD_USER_PLUGINS_ON_PLAYTEST);
}

/** Reads `<bool name="...">true|false</bool>` from a Studio settings file. */
export function parseBoolSetting(
  xml: string,
  name: string
): boolean | undefined {
  const match = new RegExp(
    `<bool name="${name}">\\s*(true|false)\\s*</bool>`
  ).exec(xml);
  return match ? match[1] === 'true' : undefined;
}

/** Studio keeps its settings beside the plugins folder on Windows and under Wine. */
function findGlobalSettingsPath(): string | undefined {
  if (process.platform !== 'win32' && process.platform !== 'linux') {
    return undefined;
  }
  try {
    const robloxDir =
      process.platform === 'linux'
        ? path.posix.dirname(findPluginsFolder())
        : path.dirname(findPluginsFolder());
    return path.join(robloxDir, 'GlobalSettings_13.xml');
  } catch {
    return undefined;
  }
}
