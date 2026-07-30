import {
  isBasePlaceVersionKeyword,
  type BasePlaceConfig,
  type BasePlaceVersionKeyword,
} from './deploy-config.js';
import {
  createEmptyDeployLock,
  loadDeployLockAsync,
  resolveDeployLockPath,
  saveDeployLockAsync,
  type DeployLock,
} from './deploy-lock.js';
import { type PlaceVersionSource } from './place-version-source.js';

/**
 * An omitted `version` means "whatever the base place currently serves", which
 * the Asset Delivery API answers with the published head. Locking it as
 * `published` is what makes a config that never opted into pinning reproducible
 * anyway; a base place that is meant to move on save asks for `"saved"`.
 */
const DEFAULT_VERSION_TYPE: BasePlaceVersionKeyword = 'published';

export interface BasePlaceResolverOptions {
  source: PlaceVersionSource;
  /**
   * Refuse to resolve anything the lock does not already answer. CI opts into
   * this so a moved base place fails the build instead of silently shipping.
   */
  frozen?: boolean;
}

interface TrackedLock {
  path: string;
  lock: DeployLock;
  dirty: boolean;
}

/**
 * Turns a `basePlace` pin into the version number to download, and owns
 * `deploy.nevermore.lock.json` while doing it.
 *
 * This is the only code allowed to read `basePlace.version` to decide what to
 * download. Everything that builds a place goes through one resolver instance
 * per run, which is what keeps lock policy from drifting between
 * `deploy run`, `batch deploy`, `test`, and `batch test`.
 *
 * One instance spans a whole run, including a batch across many packages: locks
 * are tracked per package directory, while in-flight lookups are deduplicated
 * per place id. Two packages sharing a base place therefore cost one network
 * call and still get an entry each.
 */
export class BasePlaceResolver {
  private _source: PlaceVersionSource;
  private _frozen: boolean;
  private _locks = new Map<string, TrackedLock>();
  private _inflight = new Map<number, Promise<number>>();

  constructor(options: BasePlaceResolverOptions) {
    this._source = options.source;
    this._frozen = options.frozen ?? false;
  }

  get frozen(): boolean {
    return this._frozen;
  }

  /**
   * Resolve the version to download for one base place. `packagePath` selects
   * which lock file the answer is recorded in — the one beside that package's
   * `deploy.nevermore.json`.
   */
  async resolveAsync(
    packagePath: string,
    basePlace: BasePlaceConfig
  ): Promise<number> {
    // An explicit number is already the answer, and stays out of the lock —
    // recording it would just create a second place to edit.
    if (
      basePlace.version != null &&
      !isBasePlaceVersionKeyword(basePlace.version)
    ) {
      return basePlace.version;
    }

    const versionType = basePlace.version ?? DEFAULT_VERSION_TYPE;
    const tracked = await this._getLockAsync(packagePath);
    const key = String(basePlace.placeId);
    const entry = tracked.lock.basePlaces[key];

    if (entry && entry.from === versionType) {
      return entry.version;
    }

    if (this._frozen) {
      throw new Error(
        entry
          ? `Base place ${basePlace.placeId} is locked to its ${entry.from} ` +
            `version, but deploy.nevermore.json now asks for ${versionType}. ` +
            `Run "nevermore deploy version upgrade" and commit ${tracked.path}.`
          : `Base place ${basePlace.placeId} has no entry in ${tracked.path}, ` +
            `and --frozen-lockfile forbids resolving it. Run ` +
            `"nevermore deploy version upgrade" and commit the lock file.`
      );
    }

    const version = await this._resolveVersionAsync(basePlace, versionType);
    if (entry?.version !== version || entry?.from !== versionType) {
      tracked.lock.basePlaces[key] = { version, from: versionType };
      tracked.dirty = true;
    }
    return version;
  }

  /**
   * Write every lock touched by this run. Returns the paths written so the
   * caller can report them.
   *
   * Entries for base places this run did not touch are left alone: a single
   * target's deploy must not delete the pins belonging to other targets.
   * Pruning is `deploy version upgrade`'s job, since only it walks everything.
   */
  async flushAsync(): Promise<string[]> {
    const written: string[] = [];
    for (const tracked of this._locks.values()) {
      if (!tracked.dirty) {
        continue;
      }
      await saveDeployLockAsync(tracked.path, tracked.lock);
      tracked.dirty = false;
      written.push(tracked.path);
    }
    return written;
  }

  private async _resolveVersionAsync(
    basePlace: BasePlaceConfig,
    versionType: BasePlaceVersionKeyword
  ): Promise<number> {
    // Several places in one target commonly share a base place; resolve once.
    const inflight = this._inflight.get(basePlace.placeId);
    if (inflight) {
      return inflight;
    }

    const promise = this._source.resolveLatestPlaceVersionAsync(
      basePlace.universeId,
      basePlace.placeId,
      versionType
    );
    this._inflight.set(basePlace.placeId, promise);
    try {
      return await promise;
    } catch (err) {
      // A failed lookup must not poison later attempts in the same run.
      this._inflight.delete(basePlace.placeId);
      throw err;
    }
  }

  private async _getLockAsync(packagePath: string): Promise<TrackedLock> {
    const existing = this._locks.get(packagePath);
    if (existing) {
      return existing;
    }

    const lockPath = resolveDeployLockPath(packagePath);
    const tracked: TrackedLock = {
      path: lockPath,
      lock: (await loadDeployLockAsync(lockPath)) ?? createEmptyDeployLock(),
      dirty: false,
    };
    this._locks.set(packagePath, tracked);
    return tracked;
  }
}
