import * as fs from 'fs';
import * as path from 'path';
import type { SourcemapNode } from './sourcemap-types.js';
import { SourcemapResolver } from './sourcemap-resolver.js';

/**
 * Try to load a `SourcemapResolver` for `repoRoot`, from its `sourcemap.json`
 * unless another file is given.
 *
 * Returns `undefined` if the file doesn't exist or can't be parsed — callers
 * should fall back to heuristic resolution.
 */
export function tryLoadSourcemapResolver(
  repoRoot: string,
  sourcemapPath = path.join(repoRoot, 'sourcemap.json')
): SourcemapResolver | undefined {
  let content: string;
  try {
    content = fs.readFileSync(sourcemapPath, 'utf-8');
  } catch {
    return undefined;
  }

  // A fork's build supplies this file, so a malformed tree is not fatal.
  try {
    const root = JSON.parse(content) as SourcemapNode;
    return SourcemapResolver.fromSourcemap(root, repoRoot);
  } catch {
    return undefined;
  }
}
