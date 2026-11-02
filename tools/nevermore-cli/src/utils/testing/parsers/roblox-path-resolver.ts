/**
 * Converts Roblox instance paths from Jest-lua output back to
 * repo-relative local filesystem paths.
 *
 * Two strategies:
 *
 * 1. **Sourcemap** (preferred) — Uses the authoritative `sourcemap.json`
 *    mapping from `rojo sourcemap --absolute`. Exact and handles all
 *    project layouts.
 *
 * 2. **Heuristic** (fallback) — Assumes `src/{slug}/src/` layout and
 *    hard-codes `.spec`/`.story` as known dotted suffixes. Works when no
 *    sourcemap is available.
 *
 * Paths may arrive wrapped in a Luau chunk name (`[string "..."]`) and may
 * point into a dependency's `node_modules` copy. Dependency copies are mapped
 * back to the dependency's own source package.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { SourcemapResolver } from '../../sourcemap/index.js';

const SERVER_SCRIPT_SERVICE_PREFIX = 'ServerScriptService.';
const NODE_MODULES_SEGMENT = '.node_modules.';
const QUENTY_SCOPE_SEGMENT = '@quenty.';
const CHUNK_NAME_PATTERN = /^\[string "(.*)"\]$/;
const SOURCE_EXTENSIONS = ['.lua', '.luau', '/init.lua', '/init.luau'];

export interface RobloxSourceResolveOptions {
  sourcemapResolver?: SourcemapResolver;
  /** npm name of the package under test, e.g. `@quenty/gameproductservice` */
  packageName?: string;
  /** Directory that repo-relative paths are checked against. Defaults to cwd. */
  repoRoot?: string;
}

/** Strip a Luau chunk-name wrapper: `[string "A.B"]` becomes `A.B`. */
export function unwrapChunkName(name: string): string {
  const match = name.trim().match(CHUNK_NAME_PATTERN);
  return match ? match[1] : name.trim();
}

/** Whether the instance path points into a `node_modules` copy. */
export function isDependencyInstancePath(instancePath: string): boolean {
  return instancePath.includes(NODE_MODULES_SEGMENT);
}

/**
 * Resolve a Roblox instance path (from Jest-lua or a stack trace) to a
 * repo-relative filesystem path.
 *
 * When a `sourcemapResolver` is provided, it is tried first. Falls back to
 * the heuristic if the resolver doesn't have a mapping. The result is not
 * checked for existence; see `tryResolveRobloxSourceFile`.
 */
export function resolveRobloxTestPath(
  instancePath: string,
  sourcemapResolver?: SourcemapResolver
): string {
  const sourcePath =
    _toSourceInstancePath(instancePath) ?? unwrapChunkName(instancePath);

  if (sourcemapResolver) {
    const resolved = sourcemapResolver.resolve(sourcePath);
    if (resolved) return resolved;
  }

  return _resolveHeuristic(sourcePath);
}

/**
 * Resolve a Roblox instance path to a repo-relative source file that exists.
 *
 * @returns The repo-relative path, or `undefined` when no candidate maps to a
 *   real file (vendored third-party code, truncated chunk names, ...).
 */
export function tryResolveRobloxSourceFile(
  instancePath: string,
  options: RobloxSourceResolveOptions = {}
): string | undefined {
  const sourcePath = _toSourceInstancePath(instancePath);
  if (!sourcePath) return undefined;

  const repoRoot = options.repoRoot ?? process.cwd();

  for (const candidate of _candidateInstancePaths(
    sourcePath,
    !isDependencyInstancePath(unwrapChunkName(instancePath)),
    options.packageName
  )) {
    const mapped = options.sourcemapResolver?.resolve(candidate);
    if (mapped) return mapped;

    const base = _resolveHeuristic(candidate).replace(/\.lua$/, '');
    for (const extension of SOURCE_EXTENSIONS) {
      const file = `${base}${extension}`;
      if (fs.existsSync(path.join(repoRoot, file))) return file;
    }
  }

  return undefined;
}

/**
 * Normalize to `ServerScriptService.<package>.<rest>`, where `<package>` is
 * the source package that owns the module. Returns `undefined` for paths
 * that can't belong to a repo package.
 */
function _toSourceInstancePath(instancePath: string): string | undefined {
  let sourcePath = unwrapChunkName(instancePath).replace(/:\d+$/, '');

  // Roblox truncates long chunk names: `...@quenty.servic..."]`
  if (sourcePath.endsWith('...')) return undefined;

  const nodeModulesIndex = sourcePath.lastIndexOf(NODE_MODULES_SEGMENT);
  if (nodeModulesIndex !== -1) {
    const dependencyPath = sourcePath.slice(
      nodeModulesIndex + NODE_MODULES_SEGMENT.length
    );
    if (!dependencyPath.startsWith(QUENTY_SCOPE_SEGMENT)) return undefined;
    return (
      SERVER_SCRIPT_SERVICE_PREFIX +
      dependencyPath.slice(QUENTY_SCOPE_SEGMENT.length)
    );
  }

  if (!sourcePath.startsWith(SERVER_SCRIPT_SERVICE_PREFIX)) {
    sourcePath = SERVER_SCRIPT_SERVICE_PREFIX + sourcePath;
  }
  return sourcePath;
}

/**
 * The test place names the package under test by its Rojo project name
 * (`gameproduct`), while the repo directory follows the npm name
 * (`src/gameproductservice`). Try both.
 */
function _candidateInstancePaths(
  sourcePath: string,
  isPackageUnderTest: boolean,
  packageName: string | undefined
): string[] {
  const candidates = [sourcePath];
  if (!isPackageUnderTest || !packageName) return candidates;

  const packageDir = packageName.replace(/^@[^/]+\//, '');
  const rest = sourcePath.slice(SERVER_SCRIPT_SERVICE_PREFIX.length);
  const dotIndex = rest.indexOf('.');
  const slug = dotIndex === -1 ? rest : rest.slice(0, dotIndex);
  if (slug !== packageDir) {
    candidates.push(
      SERVER_SCRIPT_SERVICE_PREFIX + packageDir + rest.slice(slug.length)
    );
  }
  return candidates;
}

/**
 * Heuristic fallback: assumes `src/{slug}/src/` layout.
 *
 * Handles optional `:LINE` suffixes and missing `ServerScriptService.` prefix.
 */
function _resolveHeuristic(instancePath: string): string {
  // Strip :LINE suffix if present
  let path = instancePath.replace(/:\d+$/, '');

  // Strip ServerScriptService. prefix
  if (path.startsWith(SERVER_SCRIPT_SERVICE_PREFIX)) {
    path = path.slice(SERVER_SCRIPT_SERVICE_PREFIX.length);
  }

  // First dot-separated segment is the package slug
  const dotIndex = path.indexOf('.');
  if (dotIndex === -1) {
    // Just a package name with no sub-path — return the src dir
    return `src/${path}/src`;
  }

  const packageSlug = path.slice(0, dotIndex);
  const remaining = path.slice(dotIndex + 1);

  // Split into segments. In Rojo, dots in filenames (e.g. "Maid.spec.lua"
  // becomes instance "Maid.spec") are ambiguous with the hierarchy separator.
  // Rejoin known filename suffixes like ".spec" and ".story" with a dot
  // instead of a slash.
  const segments = remaining.split('.');
  const rejoined: string[] = [];

  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    // If this segment is a known file suffix, merge it with the previous
    if (i > 0 && (seg === 'spec' || seg === 'story')) {
      rejoined[rejoined.length - 1] += `.${seg}`;
    } else {
      rejoined.push(seg);
    }
  }

  const subPath = rejoined.join('/');
  return `src/${packageSlug}/src/${subPath}.lua`;
}
