import * as fs from 'fs/promises';
import * as path from 'path';
import {
  BuildContext,
  resolvePackagePath,
} from '@quenty/nevermore-template-helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import {
  buildPlaceAsync,
  type BuildPlaceOptions,
  type BuiltPlace,
} from '../build/build.js';
import {
  type Deployment,
  type JobContext,
  type DeployPlaceOptions,
  type RunScriptOptions,
  type ScriptRunResult,
} from './job-context.js';
import { type OpenCloudClient } from '../open-cloud/open-cloud-client.js';

const MERGE_SCRIPT_PATH = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'transform-rojo-merge-place.luau'
);

interface SharedRojoBuild {
  promise: Promise<{ buildContext: BuildContext; rbxlPath: string }>;
  refcount: number;
}

class TrackedBuiltPlace implements BuiltPlace {
  rbxlPath: string;
  target: BuiltPlace['target'];
  sharedKey?: string;
  ownContext?: BuildContext;

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
 * Abstract base for JobContext implementations.
 *
 * Tracks every built place and guarantees cleanup in `disposeAsync` — even
 * when individual deployments fail.
 *
 * Multiple places that resolve to the same rojo project share one rojo build,
 * refcounted across `releaseBuiltPlaceAsync`. The per-place basePlace merge
 * still runs once per place against the shared output.
 */
export abstract class BaseJobContext implements JobContext {
  protected _reporter: Reporter;
  protected _openCloudClient: OpenCloudClient | undefined;
  private _builtPlaces = new Set<TrackedBuiltPlace>();
  private _sharedRojoBuilds = new Map<string, SharedRojoBuild>();

  constructor(reporter: Reporter, openCloudClient?: OpenCloudClient) {
    this._reporter = reporter;
    this._openCloudClient = openCloudClient;
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

    if (target.basePlace) {
      await this._mergeBasePlaceAsync(tracked, options);
    }

    return tracked;
  }

  private _buildCacheKey(options: BuildPlaceOptions): string | undefined {
    // Pre-built placeFile bypasses rojo entirely — nothing to share.
    if (options.overrides?.placeFile) {
      return undefined;
    }
    const packagePath = options.packagePath ?? process.cwd();
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
        options.packageName ??
        path.basename(options.packagePath ?? process.cwd());
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
        'BaseJobContext: shared rojo build returned no BuildContext'
      );
    }
    return { buildContext: result.buildContext, rbxlPath: result.rbxlPath };
  }

  private async _mergeBasePlaceAsync(
    tracked: TrackedBuiltPlace,
    options: BuildPlaceOptions
  ): Promise<void> {
    const { basePlace } = tracked.target;
    if (!basePlace || !this._openCloudClient) {
      return;
    }

    // Merge artifacts (base.rbxl, merged.rbxl) are per-place — siblings sharing
    // the rojo build would otherwise collide on filenames in one dir.
    const mergeContext = await BuildContext.createAsync({
      prefix: 'rojo-merge-',
    });

    const resolvedName = options.packageName ?? '';

    this._reporter.onPackagePhaseChange(resolvedName, 'downloading');
    OutputHelper.verbose('Downloading base place for merge...');
    const buffer = await this._openCloudClient.downloadPlaceAsync(
      basePlace.universeId,
      basePlace.placeId
    );
    const basePath = mergeContext.resolvePath('base.rbxl');
    await fs.writeFile(basePath, buffer);

    this._reporter.onPackagePhaseChange(resolvedName, 'merging');
    const packagePath = options.packagePath ?? process.cwd();
    const projectPath = path.resolve(packagePath, tracked.target.project);
    const mergedPath = mergeContext.resolvePath('merged.rbxl');

    await mergeContext.executeLuneTransformScriptAsync(
      MERGE_SCRIPT_PATH,
      basePath,
      tracked.rbxlPath,
      projectPath,
      mergedPath
    );

    tracked.rbxlPath = mergedPath;
    tracked.ownContext = mergeContext;
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

  abstract deployBuiltPlaceAsync(
    options: DeployPlaceOptions
  ): Promise<Deployment>;
  abstract runScriptAsync(
    deployment: Deployment,
    options: RunScriptOptions
  ): Promise<ScriptRunResult>;
  abstract getLogsAsync(deployment: Deployment): Promise<string>;
  abstract releaseAsync(deployment: Deployment): Promise<void>;

  async disposeAsync(): Promise<void> {
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
  }
}
