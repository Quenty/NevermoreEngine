import * as path from 'path';
import { type BuildContext } from '@quenty/nevermore-template-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import {
  type BasePlaceLockMode,
  type BasePlaceResolver,
} from '@quenty/nevermore-deploy';
import {
  buildPlaceAsync,
  type BuildPlaceOptions,
  type BuiltPlace,
} from './build-place.js';
import {
  mergeBasePlaceAsync,
  type PlaceDownloader,
} from './merge-base-place.js';

export interface PlaceBuildSessionOptions {
  reporter: Reporter;
  /** Without one (or a `resolver`), building a target with a `basePlace` fails. */
  downloader?: PlaceDownloader;
  resolver?: BasePlaceResolver;
  /** Appended when a base place can't be downloaded. */
  missingCredentialsHint?: string;
}

export interface LockFlushResult {
  writtenLockPaths: string[];
  lockWriteError?: unknown;
  lockMode?: BasePlaceLockMode;
}

interface SharedRojoBuild {
  promise: Promise<{ buildContext: BuildContext; rbxlPath: string }>;
  refcount: number;
}

class TrackedBuiltPlace implements BuiltPlace {
  rbxlPath: string;
  target: BuiltPlace['target'];
  sharedKey?: string;
  ownContext?: BuildContext;
  basePlaceVersion?: number;

  constructor(
    rbxlPath: string,
    target: BuiltPlace['target'],
    sharedKey: string | undefined,
    ownContext: BuildContext | undefined
  ) {
    this.rbxlPath = rbxlPath;
    this.target = target;
    this.sharedKey = sharedKey;
    this.ownContext = ownContext;
  }
}

/**
 * Builds places for one job. Tracks every built place and guarantees cleanup
 * in `disposeAsync`, even when individual deployments fail.
 *
 * Multiple places that resolve to the same rojo project share one rojo build,
 * refcounted across `releaseBuiltPlaceAsync`. The per-place basePlace merge
 * still runs once per place against the shared output.
 */
export class PlaceBuildSession {
  private _reporter: Reporter;
  private _downloader: PlaceDownloader | undefined;
  private _resolver: BasePlaceResolver | undefined;
  private _missingCredentialsHint: string | undefined;
  private _builtPlaces = new Set<TrackedBuiltPlace>();
  private _sharedRojoBuilds = new Map<string, SharedRojoBuild>();

  constructor(options: PlaceBuildSessionOptions) {
    this._reporter = options.reporter;
    this._downloader = options.downloader;
    this._resolver = options.resolver;
    this._missingCredentialsHint = options.missingCredentialsHint;
  }

  async buildPlaceAsync(options: BuildPlaceOptions): Promise<BuiltPlace> {
    const cacheKey = this._buildCacheKey(options);

    let rbxlPath: string;
    let target: BuiltPlace['target'];
    let sharedKey: string | undefined;
    let ownContext: BuildContext | undefined;

    if (cacheKey) {
      const shared = await this._getOrCreateSharedBuildAsync(cacheKey, options);
      rbxlPath = shared.rbxlPath;
      sharedKey = cacheKey;
      target = this._applyTargetOverrides(options.target, options.overrides);
    } else {
      const result = await buildPlaceAsync({
        ...options,
        reporter: this._reporter,
      });
      rbxlPath = result.rbxlPath;
      target = result.target;
      ownContext = result.buildContext;
    }

    const tracked = new TrackedBuiltPlace(
      rbxlPath,
      target,
      sharedKey,
      ownContext
    );
    this._builtPlaces.add(tracked);

    if (target.basePlace && !options.deferBasePlaceMerge) {
      await this._mergeBasePlaceAsync(tracked, options);
    }

    return tracked;
  }

  async releaseBuiltPlaceAsync(builtPlace: BuiltPlace): Promise<void> {
    const tracked = builtPlace as TrackedBuiltPlace;
    if (!this._builtPlaces.has(tracked)) {
      return; // already released or not ours — idempotent
    }
    this._builtPlaces.delete(tracked);

    if (tracked.ownContext) {
      await tracked.ownContext.cleanupAsync();
      tracked.ownContext = undefined;
    }

    if (tracked.sharedKey) {
      const key = tracked.sharedKey;
      tracked.sharedKey = undefined;
      const entry = this._sharedRojoBuilds.get(key);
      if (entry) {
        entry.refcount--;
        if (entry.refcount <= 0) {
          this._sharedRojoBuilds.delete(key);
          try {
            const { buildContext } = await entry.promise;
            await buildContext.cleanupAsync();
          } catch {
            // build itself failed — nothing to clean
          }
        }
      }
    }
  }

  /**
   * Clean up every built place, then write the lock file. The write is last and
   * best effort, so it can't hide the run's own error or skip cleanup.
   */
  async disposeAsync(): Promise<LockFlushResult> {
    for (const tracked of [...this._builtPlaces]) {
      await this.releaseBuiltPlaceAsync(tracked);
    }
    // Defensive — refcounts should have hit zero via releases above.
    for (const [key, entry] of this._sharedRojoBuilds) {
      try {
        const { buildContext } = await entry.promise;
        await buildContext.cleanupAsync();
      } catch {
        // best effort
      }
      this._sharedRojoBuilds.delete(key);
    }

    if (!this._resolver) {
      return { writtenLockPaths: [] };
    }
    const lockMode = this._resolver.lockMode;
    try {
      return { writtenLockPaths: await this._resolver.flushAsync(), lockMode };
    } catch (err) {
      return { writtenLockPaths: [], lockWriteError: err, lockMode };
    }
  }

  private _buildCacheKey(options: BuildPlaceOptions): string | undefined {
    // Pre-built placeFile bypasses rojo entirely — nothing to share.
    if (options.overrides?.placeFile) {
      return undefined;
    }
    const packagePath = options.packagePath;
    const projectPath = path.resolve(packagePath, options.target.project);
    const outputFileName = options.outputFileName ?? 'build.rbxl';
    return `${projectPath}|${outputFileName}`;
  }

  private _applyTargetOverrides(
    target: BuiltPlace['target'],
    overrides: BuildPlaceOptions['overrides']
  ): BuiltPlace['target'] {
    const out = { ...target };
    if (overrides?.universeId) out.universeId = overrides.universeId;
    if (overrides?.placeId) out.placeId = overrides.placeId;
    if (overrides?.scriptTemplate)
      out.scriptTemplate = overrides.scriptTemplate;
    return out;
  }

  private async _getOrCreateSharedBuildAsync(
    cacheKey: string,
    options: BuildPlaceOptions
  ): Promise<{ buildContext: BuildContext; rbxlPath: string }> {
    const existing = this._sharedRojoBuilds.get(cacheKey);
    if (existing) {
      existing.refcount++;
      // Waiter: the in-flight build was started under a different
      // packageName, so emit our own 'building' phase change for the reporter.
      const resolvedName =
        options.packageName ?? path.basename(options.packagePath);
      this._reporter.onPackagePhaseChange(resolvedName, 'building');
      return existing.promise;
    }

    const promise = this._doSharedBuildAsync(options);
    const entry: SharedRojoBuild = { promise, refcount: 1 };
    this._sharedRojoBuilds.set(cacheKey, entry);

    try {
      return await promise;
    } catch (err) {
      this._sharedRojoBuilds.delete(cacheKey);
      throw err;
    }
  }

  private async _doSharedBuildAsync(
    options: BuildPlaceOptions
  ): Promise<{ buildContext: BuildContext; rbxlPath: string }> {
    const result = await buildPlaceAsync({
      ...options,
      reporter: this._reporter,
    });
    if (!result.buildContext) {
      throw new Error(
        'PlaceBuildSession: shared rojo build returned no BuildContext'
      );
    }
    return { buildContext: result.buildContext, rbxlPath: result.rbxlPath };
  }

  private async _mergeBasePlaceAsync(
    tracked: TrackedBuiltPlace,
    options: BuildPlaceOptions
  ): Promise<void> {
    const { basePlace } = tracked.target;
    if (!basePlace) {
      return;
    }

    // Silently building without the base place would report success on a place
    // that is missing all of its Studio-authored content, so a session that
    // cannot download one says so instead.
    if (!this._downloader || !this._resolver) {
      throw new Error(
        `Target has a basePlace (${basePlace.placeId}) but this run has no Open ` +
          `Cloud access to download it.` +
          (this._missingCredentialsHint
            ? ` ${this._missingCredentialsHint}`
            : '')
      );
    }

    const merged = await mergeBasePlaceAsync({
      codeRbxlPath: tracked.rbxlPath,
      basePlace,
      projectPath:
        options.overrides?.projectFile ??
        path.resolve(options.packagePath, tracked.target.project),
      packagePath: options.packagePath,
      resolver: this._resolver,
      downloader: this._downloader,
      reporter: this._reporter,
      packageName: options.packageName ?? '',
    });

    // Carried out to the caller so it can be stamped into the place: this is
    // the only point where a "published" pin becomes a concrete number, and the
    // base place will have moved on by the time anyone asks in game.
    tracked.basePlaceVersion = merged.basePlaceVersion;
    tracked.rbxlPath = merged.rbxlPath;
    tracked.ownContext = merged.buildContext;
  }
}
