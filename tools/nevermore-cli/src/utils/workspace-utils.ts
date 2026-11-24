/**
 * Finds the packages in a project, whatever package manager owns it: every
 * workspace package for pnpm, npm and yarn workspaces, or the one package
 * when there is no workspace.
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { execa } from 'execa';
import {
  detectPackageManagerAsync,
  isSamePath,
  resolveRealPathAsync,
} from './package-manager-utils.js';

export interface WorkspacePackageInfo {
  name: string;
  path: string;
}

/** A package that would be published: named, and not `private`. */
export interface PublishablePackage {
  name: string;
  version: string;
  path: string;
  /** `repository` as written in package.json */
  repository?: string | { url?: string };
  /** `publishConfig.registry`, when the package publishes somewhere specific */
  registry?: string;
}

const WORKSPACE_MARKERS = ['pnpm-workspace.yaml', 'lerna.json'];

/**
 * The directory that owns the workspace: the nearest ancestor with a
 * workspace marker or a package.json `workspaces` field. Falls back to the
 * nearest package.json, so a single-package repo is its own root.
 */
export async function findWorkspaceRootAsync(
  startDirectory: string
): Promise<string> {
  let nearestPackage: string | undefined;

  for (const directory of await _ancestorsAsync(startDirectory)) {
    for (const marker of WORKSPACE_MARKERS) {
      if (await _existsAsync(path.join(directory, marker))) {
        return directory;
      }
    }

    const packageJson = await tryReadJsonAsync<{ workspaces?: unknown }>(
      path.join(directory, 'package.json')
    );
    if (packageJson) {
      if (packageJson.workspaces) {
        return directory;
      }
      nearestPackage ??= directory;
    }
  }

  if (!nearestPackage) {
    throw new Error(`No package.json found at or above ${startDirectory}`);
  }
  return nearestPackage;
}

/**
 * Every package in the workspace (including the root package), with absolute
 * paths. Asks the package manager, so its own workspace rules apply.
 */
export async function listWorkspacePackagesAsync(
  cwd = process.cwd()
): Promise<WorkspacePackageInfo[]> {
  const root = await findWorkspaceRootAsync(cwd);
  const packageManager = await detectPackageManagerAsync(root);

  switch (packageManager) {
    case 'pnpm': {
      const { stdout } = await execa(
        'pnpm',
        ['ls', '--json', '-r', '--depth', '-1'],
        { cwd: root }
      );
      return JSON.parse(stdout) as WorkspacePackageInfo[];
    }
    case 'npm': {
      const rootPackage = await _readRootPackageAsync(root);
      if (!rootPackage.isWorkspace) {
        return rootPackage.packages;
      }
      const { stdout } = await execa('npm', ['query', '.workspace', '--json'], {
        cwd: root,
      });
      const workspaces = JSON.parse(stdout) as WorkspacePackageInfo[];
      return [...rootPackage.packages, ...workspaces];
    }
    case 'yarn': {
      const rootPackage = await _readRootPackageAsync(root);
      if (!rootPackage.isWorkspace) {
        return rootPackage.packages;
      }
      // Yarn 2+ only; classic yarn has no machine-readable equivalent
      const { stdout } = await execa('yarn', ['workspaces', 'list', '--json'], {
        cwd: root,
      });
      return stdout
        .split('\n')
        .filter((line) => line.trim())
        .map((line) => JSON.parse(line) as { name: string; location: string })
        .map((entry) => ({
          name: entry.name,
          path: path.resolve(root, entry.location),
        }));
    }
    default: {
      const rootPackage = await _readRootPackageAsync(root);
      if (rootPackage.isWorkspace) {
        throw new Error(
          `Listing ${packageManager} workspaces isn't supported. Pass package names explicitly.`
        );
      }
      return rootPackage.packages;
    }
  }
}

/**
 * The packages a release publishes: named, not `private`, and inside
 * lerna.json's `packages` when the repo uses lerna. The workspace can be wider
 * than what lerna publishes (plugins, games), so without that filter those
 * would look like packages that never made it to npm.
 */
export async function listPublishablePackagesAsync(
  cwd = process.cwd()
): Promise<PublishablePackage[]> {
  const root = await findWorkspaceRootAsync(cwd);
  const lernaJson = await tryReadJsonAsync<{ packages?: string[] }>(
    path.join(root, 'lerna.json')
  );
  const lernaGlobs = lernaJson
    ? lernaJson.packages ?? ['packages/*']
    : undefined;

  const result: PublishablePackage[] = [];
  for (const pkg of await listWorkspacePackagesAsync(root)) {
    if (lernaGlobs) {
      const relative = path.relative(root, pkg.path).split(path.sep).join('/');
      if (!isInLernaPackages(relative, lernaGlobs)) {
        continue;
      }
    }

    const json = await tryReadJsonAsync<{
      name?: string;
      version?: string;
      private?: boolean;
      repository?: PublishablePackage['repository'];
      publishConfig?: { registry?: string };
    }>(path.join(pkg.path, 'package.json'));
    if (!json?.name || json.private) {
      continue;
    }

    result.push({
      name: json.name,
      version: json.version ?? '0.0.0',
      path: pkg.path,
      repository: json.repository,
      registry: json.publishConfig?.registry,
    });
  }

  return result.sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * The package whose directory `cwd` is in, when that isn't the workspace root.
 * Lets a command run from a package directory act on just that package.
 */
export async function findPackageContainingAsync<T extends { path: string }>(
  packages: T[],
  cwd: string,
  workspaceRoot: string
): Promise<T | undefined> {
  const realCwd = await resolveRealPathAsync(cwd);
  const realRoot = await resolveRealPathAsync(workspaceRoot);

  let best: { pkg: T; depth: number } | undefined;
  for (const pkg of packages) {
    const realPackage = await resolveRealPathAsync(pkg.path);
    if (isSamePath(realPackage, realRoot)) {
      continue;
    }
    if (_isSameOrInside(realCwd, realPackage)) {
      const depth = realPackage.length;
      if (!best || depth > best.depth) {
        best = { pkg, depth };
      }
    }
  }
  return best?.pkg;
}

/**
 * Matches lerna's `packages` globs. Only the `dir/*` form is supported;
 * anything else throws rather than guessing.
 */
export function isInLernaPackages(
  relativePath: string,
  globs: string[]
): boolean {
  return globs.some((glob) => {
    const match = /^(.+)\/\*$/.exec(glob);
    if (!match || match[1].includes('*')) {
      throw new Error(`Unsupported lerna.json packages glob: ${glob}`);
    }
    return path.posix.dirname(relativePath) === match[1];
  });
}

export async function tryReadJsonAsync<T>(
  filePath: string
): Promise<T | undefined> {
  try {
    return JSON.parse(await fs.readFile(filePath, 'utf-8')) as T;
  } catch {
    return undefined;
  }
}

async function _readRootPackageAsync(root: string): Promise<{
  isWorkspace: boolean;
  packages: WorkspacePackageInfo[];
}> {
  const json = await tryReadJsonAsync<{ name?: string; workspaces?: unknown }>(
    path.join(root, 'package.json')
  );
  return {
    isWorkspace: Boolean(json?.workspaces),
    packages: json?.name ? [{ name: json.name, path: root }] : [],
  };
}

/** Start directory and its ancestors, stopping at the home directory. */
async function _ancestorsAsync(startDirectory: string): Promise<string[]> {
  const boundary = await resolveRealPathAsync(os.homedir());
  const result: string[] = [];
  let directory = await resolveRealPathAsync(path.resolve(startDirectory));
  for (;;) {
    if (isSamePath(directory, boundary)) {
      break;
    }
    result.push(directory);
    const parent = path.dirname(directory);
    if (parent === directory) {
      break;
    }
    directory = parent;
  }
  return result;
}

function _isSameOrInside(child: string, parent: string): boolean {
  const relative = path.relative(parent, child);
  return (
    relative === '' ||
    (!relative.startsWith('..') && !path.isAbsolute(relative))
  );
}

async function _existsAsync(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}
