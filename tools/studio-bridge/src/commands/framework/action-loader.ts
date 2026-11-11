/**
 * Scans co-located `.lua` action files from the command directory tree
 * and returns their source contents for pushing to plugin sessions.
 *
 * Each command directory may contain a `.lua` file with the same stem
 * as its `.ts` file (e.g. `exec.lua` next to `exec.ts`). These files
 * are Luau modules that register action handlers in the plugin's
 * ActionRouter at runtime.
 *
 * `.spec.lua` files beside them are Jest specs. They are never pushed,
 * since anything pushed runs inside the user's Studio.
 */

import { createHash } from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { resolvePackagePath } from '@quenty/nevermore-template-helpers/resolve-template-path';

export interface ActionSource {
  /** Action module name (derived from the filename, e.g. "exec"). */
  name: string;
  /** Full Luau source code of the action module. */
  source: string;
  /** Relative path within the commands directory (for diagnostics). */
  relativePath: string;
  hash: string;
}

/**
 * Recursively scan `baseDir` for `.lua` files and return their contents
 * as `ActionSource` entries. Only files that end in `.lua` are included,
 * and `.spec.lua` files are skipped.
 */
export async function loadActionSourcesAsync(
  baseDir?: string
): Promise<ActionSource[]> {
  const dir = baseDir ?? resolvePackagePath(import.meta.url, 'src', 'commands');

  const actions: ActionSource[] = [];
  await scanDirAsync(dir, dir, actions);
  return orderByDependencies(actions);
}

const REQUIRE_PATTERN = /\brequire\(\s*["']([^"']+)["']\s*\)/g;

function orderByDependencies(actions: ActionSource[]): ActionSource[] {
  const byName = new Map(actions.map((action) => [action.name, action]));
  const ordered: ActionSource[] = [];
  const visiting = new Set<string>();
  const done = new Set<string>();

  const visit = (action: ActionSource) => {
    if (done.has(action.name)) return;
    if (visiting.has(action.name)) {
      throw new Error(
        `Action modules require each other in a cycle through '${action.name}'`
      );
    }
    visiting.add(action.name);

    const dependencyHashes: string[] = [];
    for (const match of action.source.matchAll(REQUIRE_PATTERN)) {
      const dependency = byName.get(match[1]);
      if (dependency && dependency !== action) {
        visit(dependency);
        dependencyHashes.push(dependency.hash);
      }
    }
    if (dependencyHashes.length > 0) {
      action.hash = createHash('sha256')
        .update(action.source)
        .update(dependencyHashes.join('\n'))
        .digest('hex');
    }

    visiting.delete(action.name);
    done.add(action.name);
    ordered.push(action);
  };

  for (const action of actions) {
    visit(action);
  }
  return ordered;
}

async function scanDirAsync(
  baseDir: string,
  currentDir: string,
  results: ActionSource[]
): Promise<void> {
  let entries;
  try {
    entries = await fs.readdir(currentDir, { withFileTypes: true });
  } catch {
    return;
  }

  for (const entry of entries) {
    const fullPath = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      await scanDirAsync(baseDir, fullPath, results);
    } else if (isActionFile(entry.name)) {
      const source = await fs.readFile(fullPath, 'utf-8');
      const name = path.basename(entry.name, '.lua');
      const relativePath = path.relative(baseDir, fullPath);
      const hash = createHash('sha256').update(source).digest('hex');
      results.push({ name, source, relativePath, hash });
    }
  }
}

function isActionFile(fileName: string): boolean {
  return fileName.endsWith('.lua') && !fileName.endsWith('.spec.lua');
}
