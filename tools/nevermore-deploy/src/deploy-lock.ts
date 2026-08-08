import * as fs from 'fs/promises';
import * as path from 'path';
import {
  BASE_PLACE_VERSION_KEYWORDS,
  type BasePlaceVersionKeyword,
} from './deploy-config.js';

/**
 * Bump only for a format change readers cannot absorb. A newer lock file is a
 * hard error rather than a best-effort parse — silently ignoring fields we do
 * not understand is how a lock file stops meaning anything.
 */
export const DEPLOY_LOCK_VERSION = 1;

export interface BasePlaceLockEntry {
  /** The resolved place version number. */
  version: number;
  /**
   * Which rule produced it. This is what invalidates the entry when someone
   * edits the config from `"published"` to `"saved"` — without it, flipping the
   * keyword would keep serving the previously locked version.
   */
  from: BasePlaceVersionKeyword;
}

/**
 * `deploy.nevermore.lock.json` — the resolved counterpart to
 * `deploy.nevermore.json`.
 *
 * The config states intent ("follow the published base place"); the lock states
 * fact ("that was v158 when we last looked"). Keeping them apart means bumping
 * a base place forward never has to overwrite the intent, and a commit fully
 * describes the deploy it produced.
 *
 * Keyed by base place id, matching how `deploy version upgrade` and
 * `deploy version promote` already identify base places — a base place shared
 * by several targets is one entry, and multi-place targets need no special
 * handling. There are deliberately no timestamps: git already records when an
 * entry changed, and ties it to an author and a commit.
 */
export interface DeployLock {
  lockfileVersion: number;
  basePlaces: Record<string, BasePlaceLockEntry>;
}

export function resolveDeployLockPath(packagePath: string): string {
  return path.resolve(packagePath, 'deploy.nevermore.lock.json');
}

export function createEmptyDeployLock(): DeployLock {
  return { lockfileVersion: DEPLOY_LOCK_VERSION, basePlaces: {} };
}

function _isKeyword(value: unknown): value is BasePlaceVersionKeyword {
  return (
    typeof value === 'string' &&
    (BASE_PLACE_VERSION_KEYWORDS as readonly string[]).includes(value)
  );
}

/**
 * Read a lock file. Returns undefined when there is none — that is the normal
 * state for a package that has never deployed, and the caller bootstraps one.
 *
 * A malformed or future-versioned file throws instead of being regenerated: an
 * unreadable lock is usually a bad merge, and quietly replacing it would drop
 * whatever the other side pinned.
 */
export async function loadDeployLockAsync(
  lockPath: string
): Promise<DeployLock | undefined> {
  let content: string;
  try {
    content = await fs.readFile(lockPath, 'utf-8');
  } catch {
    return undefined;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    throw new Error(
      `${lockPath} is not valid JSON (${
        err instanceof Error ? err.message : String(err)
      }). If this is a merge conflict, take either side and re-run ` +
        `"nevermore deploy version upgrade".`
    );
  }

  const lock = parsed as Partial<DeployLock>;
  if (lock.lockfileVersion !== DEPLOY_LOCK_VERSION) {
    throw new Error(
      `${lockPath} has lockfileVersion ${String(lock.lockfileVersion)}, but ` +
        `this CLI understands ${DEPLOY_LOCK_VERSION}. Update @quenty/nevermore-cli.`
    );
  }
  if (!lock.basePlaces || typeof lock.basePlaces !== 'object') {
    throw new Error(`${lockPath} is missing "basePlaces"`);
  }

  for (const [placeId, entry] of Object.entries(lock.basePlaces)) {
    if (!Number.isInteger(entry?.version) || entry.version < 1) {
      throw new Error(
        `${lockPath} entry "${placeId}" has an invalid "version" — must be a positive integer`
      );
    }
    if (!_isKeyword(entry.from)) {
      throw new Error(
        `${lockPath} entry "${placeId}" has an invalid "from" — must be ` +
          BASE_PLACE_VERSION_KEYWORDS.map((k) => `"${k}"`).join(' or ')
      );
    }
  }

  return lock as DeployLock;
}

/** Write a lock file with stable key ordering, so diffs stay reviewable. */
export async function saveDeployLockAsync(
  lockPath: string,
  lock: DeployLock
): Promise<void> {
  const basePlaces: Record<string, BasePlaceLockEntry> = {};
  for (const placeId of Object.keys(lock.basePlaces).sort()) {
    const entry = lock.basePlaces[placeId]!;
    basePlaces[placeId] = { version: entry.version, from: entry.from };
  }

  const ordered: DeployLock = {
    lockfileVersion: lock.lockfileVersion,
    basePlaces,
  };
  await fs.writeFile(lockPath, JSON.stringify(ordered, null, 2) + '\n');
}
