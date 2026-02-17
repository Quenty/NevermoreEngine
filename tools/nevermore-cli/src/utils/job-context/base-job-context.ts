import { type BuildContext } from '@quenty/nevermore-template-helpers';
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
  private _builtPlaces = new Set<TrackedBuiltPlace>();

  async buildPlaceAsync(options: BuildPlaceOptions): Promise<BuiltPlace> {
    const result = await buildPlaceAsync(options);
    const tracked = new TrackedBuiltPlace(result.rbxlPath, result.target, result.buildContext);
    this._builtPlaces.add(tracked);
    return tracked;
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

  abstract deployBuiltPlaceAsync(reporter: Reporter, options: DeployPlaceOptions): Promise<Deployment>;
  abstract runScriptAsync(deployment: Deployment, reporter: Reporter, options: RunScriptOptions): Promise<ScriptRunResult>;
  abstract getLogsAsync(deployment: Deployment): Promise<string>;
  abstract releaseAsync(deployment: Deployment): Promise<void>;

  async disposeAsync(): Promise<void> {
    for (const tracked of [...this._builtPlaces]) {
      await this.releaseBuiltPlaceAsync(tracked);
    }
  }
}
