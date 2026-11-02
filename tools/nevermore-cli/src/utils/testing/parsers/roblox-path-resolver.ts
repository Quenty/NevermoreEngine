/**
 * Maps Roblox instance paths from Jest-lua output to existing repo-relative
 * source files, through `sourcemap.json` or else the `<package dir>/src/`
 * layout.
 *
 * A package's npm name (`@quenty/playermock`), directory (`src/player-mock`),
 * Rojo project name (`playermock`) and test-place slug (`gameproduct` for
 * `src/gameproductservice`) can all differ; see `AnnotationWorkspace`.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { SourcemapResolver } from '../../sourcemap/index.js';
import type {
  AnnotationWorkspace,
  AnnotationWorkspacePackage,
} from './annotation-workspace.js';

const SERVER_SCRIPT_SERVICE_PREFIX = 'ServerScriptService.';
const NODE_MODULES_SEGMENT = '.node_modules.';
const QUENTY_SCOPE = '@quenty/';
const QUENTY_SCOPE_SEGMENT = '@quenty.';
const CHUNK_NAME_PATTERN = /^\[string "(.*)"\]$/;
// Rojo strips `.server`/`.client` from script instance names.
const SOURCE_EXTENSIONS = ['', '.server', '.client'].flatMap((kind) => [
  `${kind}.lua`,
  `${kind}.luau`,
  `/init${kind}.lua`,
  `/init${kind}.luau`,
]);

export interface RobloxSourceResolveOptions {
  sourcemapResolver?: SourcemapResolver;
  workspace?: AnnotationWorkspace;
  /** npm name of the package under test, e.g. `@quenty/gameproductservice` */
  packageName?: string;
  /** Repo root that holds the workspace. Defaults to cwd. */
  repoRoot?: string;
}

export interface ResolvedSourceFile {
  file: string;
  /** False for dependency copies and sibling packages. */
  isPackageUnderTest: boolean;
}

/**
 * Resolve an instance path (no `:LINE` suffix) to an existing repo-relative
 * source file, or `undefined` when none matches.
 */
export function tryResolveRobloxSourceFile(
  instancePath: string,
  options: RobloxSourceResolveOptions = {}
): ResolvedSourceFile | undefined {
  let unwrapped = _unwrapChunkName(instancePath);

  // Roblox truncates long chunk names: `...@quenty.servic..."]`
  if (unwrapped.endsWith('...')) return undefined;

  if (unwrapped.startsWith(SERVER_SCRIPT_SERVICE_PREFIX)) {
    unwrapped = unwrapped.slice(SERVER_SCRIPT_SERVICE_PREFIX.length);
  }

  const packagesByName = options.workspace?.packagesByName;

  let workspacePackage: AnnotationWorkspacePackage | undefined;
  let packageInstanceName: string;
  let rest: string;
  let isPackageUnderTest = false;

  const nodeModulesIndex = unwrapped.lastIndexOf(NODE_MODULES_SEGMENT);
  if (nodeModulesIndex !== -1) {
    const dependencyPath = unwrapped.slice(
      nodeModulesIndex + NODE_MODULES_SEGMENT.length
    );
    if (!dependencyPath.startsWith(QUENTY_SCOPE_SEGMENT)) return undefined;
    [packageInstanceName, rest] = _splitFirstSegment(
      dependencyPath.slice(QUENTY_SCOPE_SEGMENT.length)
    );
    workspacePackage = packagesByName?.get(QUENTY_SCOPE + packageInstanceName);
  } else {
    [packageInstanceName, rest] = _splitFirstSegment(unwrapped);
    const packageUnderTest = options.packageName
      ? packagesByName?.get(options.packageName)
      : undefined;
    if (packageUnderTest?.testSlugs.includes(packageInstanceName)) {
      workspacePackage = packageUnderTest;
      isPackageUnderTest = true;
    }
  }

  const dir = workspacePackage?.dir ?? `src/${packageInstanceName}`;
  // The sourcemap names packages by Rojo project name, not folder.
  const sourcemapNames = new Set([
    workspacePackage?.projectName ?? packageInstanceName,
    path.posix.basename(dir),
  ]);
  for (const name of sourcemapNames) {
    const mapped = options.sourcemapResolver?.resolve(
      SERVER_SCRIPT_SERVICE_PREFIX + name + (rest ? `.${rest}` : '')
    );
    if (mapped) return { file: mapped, isPackageUnderTest };
  }

  const repoRoot = options.repoRoot ?? process.cwd();
  const base = _resolveHeuristic(dir, rest);
  for (const extension of SOURCE_EXTENSIONS) {
    const file = `${base}${extension}`;
    if (fs.existsSync(path.join(repoRoot, file))) {
      return { file, isPackageUnderTest };
    }
  }

  return undefined;
}

function _unwrapChunkName(name: string): string {
  const match = name.trim().match(CHUNK_NAME_PATTERN);
  return match ? match[1] : name.trim();
}

function _splitFirstSegment(dottedPath: string): [string, string] {
  const dotIndex = dottedPath.indexOf('.');
  return dotIndex === -1
    ? [dottedPath, '']
    : [dottedPath.slice(0, dotIndex), dottedPath.slice(dotIndex + 1)];
}

function _resolveHeuristic(dir: string, rest: string): string {
  if (!rest) return `${dir}/src`;

  // Rojo turns `Maid.spec.lua` into instance `Maid.spec`, so rejoin suffixes.
  const rejoined: string[] = [];
  for (const segment of rest.split('.')) {
    if (rejoined.length > 0 && (segment === 'spec' || segment === 'story')) {
      rejoined[rejoined.length - 1] += `.${segment}`;
    } else {
      rejoined.push(segment);
    }
  }

  return `${dir}/src/${rejoined.join('/')}`;
}
