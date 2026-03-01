/**
 * Scans co-located `.luau` action files from the command directory tree
 * and returns their source contents for pushing to plugin sessions.
 *
 * Each command directory may contain a `.luau` file with the same stem
 * as its `.ts` file (e.g. `exec.luau` next to `exec.ts`). These files
 * are Luau modules that register action handlers in the plugin's
 * ActionRouter at runtime.
 */

import { createHash } from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { resolvePackagePath } from '@quenty/nevermore-template-helpers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ActionSource {
  /** Action module name (derived from the filename, e.g. "exec"). */
  name: string;
  /** Full Luau source code of the action module. */
  source: string;
  /** Relative path within the commands directory (for diagnostics). */
  relativePath: string;
  /** SHA-256 hex digest of the source content. */
  hash: string;
}

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

/**
 * Recursively scan `baseDir` for `.luau` files and return their contents
 * as `ActionSource` entries. Only files that end in `.luau` are included.
 */
export async function loadActionSourcesAsync(
  baseDir?: string,
): Promise<ActionSource[]> {
  const dir = baseDir ?? resolvePackagePath(
    import.meta.url,
    'src', 'commands',
  );

  const actions: ActionSource[] = [];
  await scanDirAsync(dir, dir, actions);
  return actions;
}

async function scanDirAsync(
  baseDir: string,
  currentDir: string,
  results: ActionSource[],
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
    } else if (entry.name.endsWith('.luau')) {
      const source = await fs.readFile(fullPath, 'utf-8');
      const name = path.basename(entry.name, '.luau');
      const relativePath = path.relative(baseDir, fullPath);
      const hash = createHash('sha256').update(source).digest('hex');
      results.push({ name, source, relativePath, hash });
    }
  }
}
