import * as fs from 'fs';
import * as path from 'path';
import type { SourcemapNode } from './sourcemap-types.js';
import { SourcemapResolver } from './sourcemap-resolver.js';

/**
 * Try to load a `SourcemapResolver` from `sourcemap.json` in the given
 * directory.
 *
 * Returns `undefined` if the file doesn't exist or can't be parsed — callers
 * should fall back to heuristic resolution.
 */
export function tryLoadSourcemapResolver(
  repoRoot: string
): SourcemapResolver | undefined {
  const sourcemapPath = path.join(repoRoot, 'sourcemap.json');

  let content: string;
  try {
    content = fs.readFileSync(sourcemapPath, 'utf-8');
  } catch {
    return undefined;
  }

  let root: SourcemapNode;
  try {
    root = JSON.parse(content) as SourcemapNode;
  } catch {
    return undefined;
  }

  return SourcemapResolver.fromSourcemap(root, repoRoot);
}
