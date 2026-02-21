import * as fs from 'fs/promises';
import * as path from 'path';
import { type BuildContext, resolvePackagePath } from '@quenty/nevermore-template-helpers';
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
  'build-scripts', 'transform-rojo-merge-place.luau'
);

/**
 * Internal wrapper — implements BuiltPlace with an internal BuildContext
 * that callers never see. Only BaseJobContext touches buildContext.
 */
class TrackedBuiltPlace implements BuiltPlace {
  rbxlPath: string;
  target: BuiltPlace['target'];
  buildContext?: BuildContext;

  constructor(rbxlPath: string, target: BuiltPlace['target'], buildContext?: BuildContext) {
    this.rbxlPath = rbxlPath;
    this.target = target;
    this.buildContext = buildContext;
  }
}

/**
 * Abstract base for JobContext implementations.
 * Tracks every built place and guarantees cleanup in `disposeAsync`
 * — even when individual deployments fail.
 */
export abstract class BaseJobContext implements JobContext {
  protected _reporter: Reporter;
  protected _openCloudClient: OpenCloudClient | undefined;
  private _builtPlaces = new Set<TrackedBuiltPlace>();

  constructor(reporter: Reporter, openCloudClient?: OpenCloudClient) {
    this._reporter = reporter;
    this._openCloudClient = openCloudClient;
  }

  async buildPlaceAsync(options: BuildPlaceOptions): Promise<BuiltPlace> {
    const result = await buildPlaceAsync({ ...options, reporter: this._reporter });
    const tracked = new TrackedBuiltPlace(result.rbxlPath, result.target, result.buildContext);
    this._builtPlaces.add(tracked);

    // When a basePlace is configured, download it and merge with the rojo-built code
    if (result.target.basePlace && result.buildContext) {
      await this._mergeBasePlaceAsync(tracked, result.buildContext, options);
    }

    return tracked;
  }

  private async _mergeBasePlaceAsync(
    tracked: TrackedBuiltPlace,
    buildContext: BuildContext,
    options: BuildPlaceOptions
  ): Promise<void> {
    const { basePlace } = tracked.target;
    if (!basePlace || !this._openCloudClient) {
      return;
    }

    const resolvedName = options.packageName ?? '';

    this._reporter.onPackagePhaseChange(resolvedName, 'downloading');
    OutputHelper.verbose('Downloading base place for merge...');
    const buffer = await this._openCloudClient.downloadPlaceAsync(
      basePlace.universeId,
      basePlace.placeId
    );
    const basePath = buildContext.resolvePath('base.rbxl');
    await fs.writeFile(basePath, buffer);

    this._reporter.onPackagePhaseChange(resolvedName, 'merging');
    const packagePath = options.packagePath ?? process.cwd();
    const projectPath = path.resolve(packagePath, tracked.target.project);
    const mergedPath = buildContext.resolvePath('merged.rbxl');

    await buildContext.executeLuneTransformScriptAsync(
      MERGE_SCRIPT_PATH,
      basePath,
      tracked.rbxlPath,
      projectPath,
      mergedPath
    );

    tracked.rbxlPath = mergedPath;
  }

  async releaseBuiltPlaceAsync(builtPlace: BuiltPlace): Promise<void> {
    const tracked = builtPlace as TrackedBuiltPlace;
    if (!this._builtPlaces.has(tracked)) {
      return; // already released or not ours — idempotent
    }
    await tracked.buildContext?.cleanupAsync();
    tracked.buildContext = undefined;
    this._builtPlaces.delete(tracked);
  }

  abstract deployBuiltPlaceAsync(options: DeployPlaceOptions): Promise<Deployment>;
  abstract runScriptAsync(deployment: Deployment, options: RunScriptOptions): Promise<ScriptRunResult>;
  abstract getLogsAsync(deployment: Deployment): Promise<string>;
  abstract releaseAsync(deployment: Deployment): Promise<void>;

  async disposeAsync(): Promise<void> {
    for (const tracked of [...this._builtPlaces]) {
      await this.releaseBuiltPlaceAsync(tracked);
    }
  }
}
