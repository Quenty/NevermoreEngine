/**
 * Detects which package manager owns a project so commands install with the
 * same tool the project was set up with.
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';

export const PACKAGE_MANAGERS = ['pnpm', 'npm', 'yarn', 'bun'] as const;

export type PackageManager = typeof PACKAGE_MANAGERS[number];

export const DEFAULT_PACKAGE_MANAGER: PackageManager = 'pnpm';

const LOCKFILES: ReadonlyArray<readonly [string, PackageManager]> = [
  ['pnpm-lock.yaml', 'pnpm'],
  ['pnpm-workspace.yaml', 'pnpm'],
  ['bun.lock', 'bun'],
  ['bun.lockb', 'bun'],
  ['yarn.lock', 'yarn'],
  ['package-lock.json', 'npm'],
];

export function isPackageManager(value: string): value is PackageManager {
  return (PACKAGE_MANAGERS as readonly string[]).includes(value);
}

function parsePackageManagerField(value: unknown): PackageManager | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }

  const name = value.split('@')[0]?.trim();
  if (name && isPackageManager(name)) {
    return name;
  }

  return undefined;
}

async function detectInDirectoryAsync(
  directory: string
): Promise<PackageManager | undefined> {
  try {
    const contents = await fs.readFile(
      path.join(directory, 'package.json'),
      'utf-8'
    );
    const parsed = JSON.parse(contents) as { packageManager?: unknown };
    const declared = parsePackageManagerField(parsed.packageManager);
    if (declared) {
      return declared;
    }
  } catch {
    // No readable package.json here, fall through to lockfiles
  }

  for (const [fileName, packageManager] of LOCKFILES) {
    try {
      await fs.access(path.join(directory, fileName));
      return packageManager;
    } catch {
      continue;
    }
  }

  return undefined;
}

/**
 * Detects the package manager for a project, walking up from the given
 * directory so this works from a subfolder of the project.
 *
 * A `packageManager` field wins over a lockfile in the same directory, and the
 * nearest directory with either wins over anything further up. Falls back to
 * pnpm: Nevermore projects are pnpm projects — the templates pin it and gate it
 * behind `only-allow pnpm` — so pnpm is the right guess for a directory that
 * hasn't declared anything yet.
 */
export async function detectPackageManagerAsync(
  startDirectory: string
): Promise<PackageManager> {
  let directory = await resolveRealPathAsync(path.resolve(startDirectory));
  // Walking to the filesystem root adopts lockfiles that belong to nobody. A
  // stray package-lock.json in a home directory — npm leaves one behind after a
  // single `npm install` run there — made every project below it detect as npm,
  // and in this monorepo that means installing with the one tool that rejects
  // `workspace:` ranges outright. Nothing above the home directory can be part
  // of the project, so the search stops there.
  const boundary = await resolveRealPathAsync(os.homedir());

  for (;;) {
    if (boundary !== undefined && isSamePath(directory, boundary)) {
      break;
    }

    const detected = await detectInDirectoryAsync(directory);
    if (detected) {
      return detected;
    }

    const parent = path.dirname(directory);
    if (parent === directory) {
      break;
    }
    directory = parent;
  }

  return DEFAULT_PACKAGE_MANAGER;
}

/**
 * Resolve symlinks and, on Windows, 8.3 short names — `C:\Users\JAMESO~1` and
 * `C:\Users\James Onnen` are the same directory and must compare equal.
 * Returns the input unchanged when the path does not exist.
 */
async function resolveRealPathAsync(target: string): Promise<string> {
  try {
    return await fs.realpath(target);
  } catch {
    return target;
  }
}

/** Windows paths are case-insensitive; POSIX ones are not. */
function isSamePath(left: string, right: string): boolean {
  if (process.platform === 'win32') {
    return left.toLowerCase() === right.toLowerCase();
  }
  return left === right;
}

/**
 * Builds the command that adds dependencies to a project. Only npm spells this
 * `install`; the rest treat a bare `install` as "install the lockfile" and need
 * `add` to record new dependencies.
 */
export function buildAddPackagesCommand(
  packageManager: PackageManager,
  packages: string[]
): { command: string; args: string[] } {
  if (packageManager === 'npm') {
    return { command: 'npm', args: ['install', ...packages] };
  }

  return { command: packageManager, args: ['add', ...packages] };
}
