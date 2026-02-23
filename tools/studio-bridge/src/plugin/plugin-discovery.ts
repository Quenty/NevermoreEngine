/**
 * Utilities for detecting whether the persistent Studio Bridge plugin
 * is installed in the Roblox Studio plugins folder.
 */

import * as fs from 'fs';
import * as path from 'path';
import { findPluginsFolder } from '../process/studio-process-manager.js';

const PERSISTENT_PLUGIN_FILENAME = 'StudioBridgePersistentPlugin.rbxm';

export function getPersistentPluginPath(): string {
  return path.join(findPluginsFolder(), PERSISTENT_PLUGIN_FILENAME);
}

export function isPersistentPluginInstalled(): boolean {
  return fs.existsSync(getPersistentPluginPath());
}
