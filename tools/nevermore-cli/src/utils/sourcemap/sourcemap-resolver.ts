import * as path from 'path';
import type { SourcemapNode } from './sourcemap-types.js';

/**
 * Builds a lookup index from a Rojo sourcemap tree so that dotted Roblox
 * instance paths (e.g. `ServerScriptService.maid.Shared.Maid.spec`) can be
 * resolved to repo-relative filesystem paths.
 */
export class SourcemapResolver {
  private readonly _index: Map<string, string>;

  private constructor(index: Map<string, string>) {
    this._index = index;
  }

  /**
   * Build a resolver from a parsed sourcemap root node.
   *
   * @param root - The top-level sourcemap node (typically named after the project)
   * @param repoRoot - Absolute path to the repo root, used to convert absolute
   *   `filePaths` entries to repo-relative paths
   * @param rootAlias - The Roblox service name that the root node maps to in
   *   test output. Defaults to `"ServerScriptService"`.
   */
  static fromSourcemap(
    root: SourcemapNode,
    repoRoot: string,
    rootAlias = 'ServerScriptService'
  ): SourcemapResolver {
    const index = new Map<string, string>();
    _walkNode(root, rootAlias, repoRoot, index);
    return new SourcemapResolver(index);
  }

  /**
   * Resolve a Roblox instance path to a repo-relative filesystem path.
   *
   * Strips any trailing `:LINE` suffix before lookup.
   *
   * @returns The repo-relative path, or `undefined` if the instance path is
   *   not in the sourcemap.
   */
  resolve(instancePath: string): string | undefined {
    const cleaned = instancePath.replace(/:\d+$/, '');
    return this._index.get(cleaned);
  }
}

/** Recursively walk the sourcemap tree, populating the index map. */
function _walkNode(
  node: SourcemapNode,
  dottedPath: string,
  repoRoot: string,
  index: Map<string, string>
): void {
  const luaFile = _findLuaFilePath(node.filePaths);
  if (luaFile) {
    const relative = path.relative(repoRoot, luaFile);
    index.set(dottedPath, relative);
  }

  if (!node.children) return;

  for (const child of node.children) {
    _walkNode(child, `${dottedPath}.${child.name}`, repoRoot, index);
  }
}

/** Return the first `.lua` or `.luau` file path from a node's filePaths. */
function _findLuaFilePath(filePaths?: string[]): string | undefined {
  if (!filePaths) return undefined;
  return filePaths.find(
    (fp) => fp.endsWith('.lua') || fp.endsWith('.luau')
  );
}
