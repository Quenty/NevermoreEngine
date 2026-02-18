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
 */

import type { SourcemapResolver } from '../../sourcemap/index.js';

const SSS_PREFIX = 'ServerScriptService.';

/**
 * Resolve a Roblox instance path (from Jest-lua or a stack trace) to a
 * repo-relative filesystem path.
 *
 * When a `sourcemapResolver` is provided, it is tried first. Falls back to
 * the heuristic if the resolver doesn't have a mapping.
 */
export function resolveRobloxTestPath(
  instancePath: string,
  sourcemapResolver?: SourcemapResolver
): string {
  if (sourcemapResolver) {
    const resolved = sourcemapResolver.resolve(instancePath);
    if (resolved) return resolved;
  }

  return _resolveHeuristic(instancePath);
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
  if (path.startsWith(SSS_PREFIX)) {
    path = path.slice(SSS_PREFIX.length);
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
    if (
      i > 0 &&
      (seg === 'spec' || seg === 'story')
    ) {
      rejoined[rejoined.length - 1] += `.${seg}`;
    } else {
      rejoined.push(seg);
    }
  }

  const subPath = rejoined.join('/');
  return `src/${packageSlug}/src/${subPath}.lua`;
}
