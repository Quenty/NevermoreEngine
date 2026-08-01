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
  /**
   * Re-resolve `"saved"`/`"published"` pins instead of reusing the locked
   * answer, and write what comes back.
   *
   * This is what makes a watch-dispatched rebuild do anything. The lock holds a
   * keyword pin still until `deploy version upgrade` moves it, so a build
   * triggered *because* the base place moved would otherwise download the
   * version it was already locked to and republish an identical place. Numeric
   * pins are untouched — those are a deliberate "hold still".
   *
   * Mutually exclusive with `frozen`, which says the opposite thing.
   */
  refresh?: boolean;
}

interface TrackedLock {
  path: string;
  lock: DeployLock;
  dirty: boolean;
  /** Version type each base place was resolved as during this run. */
  claims: Map<string, BasePlaceVersionKeyword>;
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
  private _refresh: boolean;
  // Keyed on the promise, not the resolved value: concurrent callers for one
  // package must share the same TrackedLock, or whichever finishes second
  // replaces the first and its recorded entries are never written.
  private _locks = new Map<string, Promise<TrackedLock>>();
  private _inflight = new Map<string, Promise<number>>();

  constructor(options: BasePlaceResolverOptions) {
    if (options.frozen && options.refresh) {
      throw new Error(
        'A base place resolver cannot be both frozen and refreshing: one ' +
          'forbids resolving base places, the other forces it.'
      );
    }
    this._source = options.source;
    this._frozen = options.frozen ?? false;
    this._refresh = options.refresh ?? false;
  }

  get frozen(): boolean {
    return this._frozen;
  }

  get refreshing(): boolean {
    return this._refresh;
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

    // `refresh` deliberately falls through to a live lookup: the locked answer
    // is exactly what a watch-triggered rebuild must not reuse.
    if (entry && entry.from === versionType && !this._refresh) {
      return entry.version;
    }

    if (this._frozen) {
      // `deploy version upgrade` only writes the lock for an explicit keyword;
      // an absent pin is treated as a config pin and gets a number written
      // there instead, so pointing at the lock file would be a dead end.
      const remedy =
        basePlace.version == null
          ? `Run "nevermore deploy version upgrade" — an unpinned basePlace is ` +
            `pinned in deploy.nevermore.json — and commit the result.`
          : `Run "nevermore deploy version upgrade" and commit ${tracked.path}.`;
      throw new Error(
        entry
          ? `Base place ${basePlace.placeId} is locked to its ${entry.from} ` +
            `version, but deploy.nevermore.json now asks for ${versionType}. ` +
            remedy
          : `Base place ${basePlace.placeId} has no entry in ${tracked.path}, ` +
            `and --frozen-lockfile forbids resolving it. ${remedy}`
      );
    }

    const version = await this._resolveVersionAsync(basePlace, versionType);

    // One entry per base place means one version type per base place. Two
    // targets tracking the same base place as "saved" and "published" would
    // otherwise overwrite each other on every run, and never satisfy
    // --frozen-lockfile, so say so instead of writing a lock that churns.
    const claimed = tracked.claims.get(key);
    if (claimed && claimed !== versionType) {
      throw new Error(
        `Base place ${basePlace.placeId} is tracked as both "${claimed}" and ` +
          `"${versionType}" in the same deploy. The lock records one version ` +
          `per base place, so pick one keyword for it, or pin an explicit ` +
          `version number.`
      );
    }
    tracked.claims.set(key, versionType);

    if (entry?.version !== version || entry?.from !== versionType) {
      tracked.lock.basePlaces[key] = { version, from: versionType };
      tracked.dirty = true;
    }
    return version;
  }

  /**
   * Read the version a base place currently resolves to, without recording
   * anything. Returns undefined for a base place the lock does not answer.
   *
   * Watch registration uses this to say what it is watching *from*, and must not
   * disturb the lock while doing so — asking a question is not a deploy.
   */
  async peekAsync(
    packagePath: string,
    basePlace: BasePlaceConfig
  ): Promise<number | undefined> {
    if (
      basePlace.version != null &&
      !isBasePlaceVersionKeyword(basePlace.version)
    ) {
      return basePlace.version;
    }
    const versionType = basePlace.version ?? DEFAULT_VERSION_TYPE;
    const tracked = await this._getLockAsync(packagePath);
    const entry = tracked.lock.basePlaces[String(basePlace.placeId)];
    return entry?.from === versionType ? entry.version : undefined;
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
    for (const pending of this._locks.values()) {
      const tracked = await pending;
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
    // The version type is part of the key — the newest saved and the newest
    // published version of one place are different questions.
    const key = `${basePlace.placeId}:${versionType}`;
    const inflight = this._inflight.get(key);
    if (inflight) {
      return inflight;
    }

    const promise = this._source.resolveLatestPlaceVersionAsync(
      basePlace.universeId,
      basePlace.placeId,
      versionType
    );
    this._inflight.set(key, promise);
    try {
      return await promise;
    } catch (err) {
      // A failed lookup must not poison later attempts in the same run.
      this._inflight.delete(key);
      throw err;
    }
  }

  private _getLockAsync(packagePath: string): Promise<TrackedLock> {
    const existing = this._locks.get(packagePath);
    if (existing) {
      return existing;
    }

    // Stored before the first await so concurrent callers queue on this same
    // promise rather than each loading their own copy of the lock.
    const pending = (async (): Promise<TrackedLock> => {
      const lockPath = resolveDeployLockPath(packagePath);
      return {
        path: lockPath,
        lock: (await loadDeployLockAsync(lockPath)) ?? createEmptyDeployLock(),
        dirty: false,
        claims: new Map(),
      };
    })();
    this._locks.set(packagePath, pending);
    // An unreadable lock must not stay cached as a rejection that flushAsync
    // would then rethrow over the top of the real error.
    void pending.catch(() => this._locks.delete(packagePath));
    return pending;
  }
}
