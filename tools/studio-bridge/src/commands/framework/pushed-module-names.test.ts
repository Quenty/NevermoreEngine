import * as fs from 'fs';
import * as path from 'path';
import { describe, it, expect } from 'vitest';
import { getPluginPackageDir } from '../../plugin/plugin-package-dir.js';
import { loadActionSourcesAsync } from './action-loader.js';

function collectModuleNames(dir: string, names: Map<string, string>): void {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules') {
        collectModuleNames(fullPath, names);
      }
    } else if (
      entry.name.endsWith('.lua') &&
      !entry.name.endsWith('.spec.lua')
    ) {
      const stem = path.basename(entry.name, '.lua');
      const name = stem === 'init' ? path.basename(dir) : stem;
      names.set(name, fullPath);
    }
  }
}

function getPluginModuleNames(): Map<string, string> {
  const pluginDir = getPluginPackageDir();
  const names = new Map<string, string>();
  collectModuleNames(path.join(pluginDir, 'src', 'modules'), names);

  const { dependencies = {} } = JSON.parse(
    fs.readFileSync(path.join(pluginDir, 'package.json'), 'utf-8')
  ) as { dependencies?: Record<string, string> };
  for (const dependency of Object.keys(dependencies)) {
    const dependencyDir = fs.realpathSync(
      path.join(pluginDir, 'node_modules', dependency)
    );
    collectModuleNames(path.join(dependencyDir, 'src'), names);
  }
  return names;
}

describe('pushed module names', () => {
  it('finds the plugin modules it checks against', () => {
    const names = getPluginModuleNames();

    expect(names.has('ActionRouter')).toBe(true);
    expect(names.has('Maid')).toBe(true);
  });

  it('match no module in the plugin or its packages', async () => {
    const pluginNames = getPluginModuleNames();
    const clashes = (await loadActionSourcesAsync())
      .filter((action) => pluginNames.has(action.name))
      .map(
        (action) =>
          `${action.relativePath} clashes with ${pluginNames.get(action.name)}`
      );

    expect(clashes).toEqual([]);
  });
});
