/**
 * Maps Roblox instance paths from Jest-lua output to existing repo-relative
 * source files, through `sourcemap.json` or else the `src/{folder}/src/` layout.
 *
 * A package's npm name (`@quenty/playermock`), `src/` folder (`player-mock`),
 * Rojo project name (`playermock`) and test-place slug (`gameproduct` for
 * `src/gameproductservice`) can all differ.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { SourcemapResolver } from '../../sourcemap/index.js';
import {
  type TestRojoProject,
  findTestProjectSlug,
} from '../runner/test-project-slug.js';

const SERVER_SCRIPT_SERVICE_PREFIX = 'ServerScriptService.';
const NODE_MODULES_SEGMENT = '.node_modules.';
const QUENTY_SCOPE = '@quenty/';
const QUENTY_SCOPE_SEGMENT = '@quenty.';
const CHUNK_NAME_PATTERN = /^\[string "(.*)"\]$/;
const SOURCE_EXTENSIONS = ['.lua', '.luau', '/init.lua', '/init.luau'];
const DEFAULT_TEST_PROJECT = 'test/default.project.json';

export interface RobloxSourceResolveOptions {
  sourcemapResolver?: SourcemapResolver;
  /** npm name of the package under test, e.g. `@quenty/gameproductservice` */
  packageName?: string;
  /** Repo root that holds `src/`. Defaults to cwd. */
  repoRoot?: string;
}

export interface ResolvedSourceFile {
  file: string;
  /** False for dependency copies and sibling packages. */
  isPackageUnderTest: boolean;
}

interface WorkspacePackage {
  folder: string;
  projectName?: string;
  /** `undefined` until read, `null` when there is no test project */
  testSlug?: string | null;
}

interface WorkspaceIndex {
  packagesByNpmName: Map<string, WorkspacePackage>;
}

const _workspaceIndexCache = new Map<string, WorkspaceIndex>();

/** Strip a Luau chunk-name wrapper: `[string "A.B"]` becomes `A.B`. */
export function unwrapChunkName(name: string): string {
  const match = name.trim().match(CHUNK_NAME_PATTERN);
  return match ? match[1] : name.trim();
}

/**
 * Resolve an instance path (no `:LINE` suffix) to an existing repo-relative
 * source file, or `undefined` when none matches.
 */
export function tryResolveRobloxSourceFile(
  instancePath: string,
  options: RobloxSourceResolveOptions = {}
): ResolvedSourceFile | undefined {
  let unwrapped = unwrapChunkName(instancePath);

  // Roblox truncates long chunk names: `...@quenty.servic..."]`
  if (unwrapped.endsWith('...')) return undefined;

  if (unwrapped.startsWith(SERVER_SCRIPT_SERVICE_PREFIX)) {
    unwrapped = unwrapped.slice(SERVER_SCRIPT_SERVICE_PREFIX.length);
  }

  const repoRoot = options.repoRoot ?? process.cwd();
  const workspace = _getWorkspaceIndex(repoRoot);

  let workspacePackage: WorkspacePackage | undefined;
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
    workspacePackage = workspace.packagesByNpmName.get(
      QUENTY_SCOPE + packageInstanceName
    );
  } else {
    [packageInstanceName, rest] = _splitFirstSegment(unwrapped);
    const packageUnderTest = options.packageName
      ? workspace.packagesByNpmName.get(options.packageName)
      : undefined;
    if (
      packageUnderTest &&
      packageInstanceName === _getTestSlug(repoRoot, packageUnderTest)
    ) {
      workspacePackage = packageUnderTest;
      isPackageUnderTest = true;
    }
  }

  const folder = workspacePackage?.folder ?? packageInstanceName;
  // The sourcemap names packages by Rojo project name, not folder.
  const sourcemapNames = new Set([
    workspacePackage?.projectName ?? packageInstanceName,
    folder,
  ]);
  for (const name of sourcemapNames) {
    const mapped = options.sourcemapResolver?.resolve(
      SERVER_SCRIPT_SERVICE_PREFIX + name + (rest ? `.${rest}` : '')
    );
    if (mapped) return { file: mapped, isPackageUnderTest };
  }

  const base = _resolveHeuristic(folder, rest);
  for (const extension of SOURCE_EXTENSIONS) {
    const file = `${base}${extension}`;
    if (fs.existsSync(path.join(repoRoot, file))) {
      return { file, isPackageUnderTest };
    }
  }

  return undefined;
}

function _splitFirstSegment(dottedPath: string): [string, string] {
  const dotIndex = dottedPath.indexOf('.');
  return dotIndex === -1
    ? [dottedPath, '']
    : [dottedPath.slice(0, dotIndex), dottedPath.slice(dotIndex + 1)];
}

function _getWorkspaceIndex(repoRoot: string): WorkspaceIndex {
  const cached = _workspaceIndexCache.get(repoRoot);
  if (cached) return cached;

  const packagesByNpmName = new Map<string, WorkspacePackage>();
  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(path.join(repoRoot, 'src'), {
      withFileTypes: true,
    });
  } catch {
    entries = [];
  }

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const packageDir = path.join(repoRoot, 'src', entry.name);
    const npmName = _tryReadJson<{ name?: string }>(
      path.join(packageDir, 'package.json')
    )?.name;
    if (!npmName) continue;

    packagesByNpmName.set(npmName, {
      folder: entry.name,
      projectName: _tryReadJson<{ name?: string }>(
        path.join(packageDir, 'default.project.json')
      )?.name,
    });
  }

  const index = { packagesByNpmName };
  _workspaceIndexCache.set(repoRoot, index);
  return index;
}

function _getTestSlug(
  repoRoot: string,
  workspacePackage: WorkspacePackage
): string | undefined {
  if (workspacePackage.testSlug === undefined) {
    const packageDir = path.join(repoRoot, 'src', workspacePackage.folder);
    const deployConfig = _tryReadJson<{
      targets?: { test?: { project?: string } };
    }>(path.join(packageDir, 'deploy.nevermore.json'));
    const project = _tryReadJson<TestRojoProject>(
      path.join(
        packageDir,
        deployConfig?.targets?.test?.project ?? DEFAULT_TEST_PROJECT
      )
    );
    workspacePackage.testSlug =
      (project && findTestProjectSlug(project)) ?? null;
  }
  return workspacePackage.testSlug ?? undefined;
}

function _tryReadJson<T>(filePath: string): T | undefined {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf-8')) as T;
  } catch {
    return undefined;
  }
}

function _resolveHeuristic(folder: string, rest: string): string {
  if (!rest) return `src/${folder}/src`;

  // Rojo turns `Maid.spec.lua` into instance `Maid.spec`, so rejoin suffixes.
  const rejoined: string[] = [];
  for (const segment of rest.split('.')) {
    if (rejoined.length > 0 && (segment === 'spec' || segment === 'story')) {
      rejoined[rejoined.length - 1] += `.${segment}`;
    } else {
      rejoined.push(segment);
    }
  }

  return `src/${folder}/src/${rejoined.join('/')}`;
}
