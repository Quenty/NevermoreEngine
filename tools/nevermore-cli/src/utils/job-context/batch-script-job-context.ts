import * as fs from 'fs/promises';
import {
  type BuildContext,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import {
  type BuiltPlace,
  type Deployment,
  type DeployPlaceOptions,
  type JobContext,
  type RunScriptOptions,
  type ScriptRunResult,
} from './job-context.js';
import { type BuildPlaceOptions } from '../build/build.js';
import { type BatchTarget } from '../batch/changed-packages-utils.js';
import {
  type CombinedBuildProgress,
  type CombinedProjectResult,
  generateCombinedProjectAsync,
} from '../testing/runner/combined-project-generator.js';
import {
  type BatchPackageResult,
  parseBatchTestLogs,
} from '../testing/parsers/batch-log-parser.js';

/** Per-package deployment handle. Wraps a shared inner deployment. */
class BatchDeployment implements Deployment {
  constructor(
    public readonly packageName: string,
    public readonly inner: Deployment
  ) {}
}

interface CombinedBuildState {
  combinedResult: CombinedProjectResult;
  rbxlPath: string;
}

/**
 * JobContext wrapper that batches all packages into a single build, upload, and
 * execution. Wraps an inner context (cloud or local) and intercepts all methods
 * using the lazy-promise pattern: the first concurrent call triggers the shared
 * operation, all others await the same promise.
 */
export class BatchScriptJobContext implements JobContext {
  private _inner: JobContext;
  private _batchTargets: BatchTarget[];
  private _repoRoot: string;
  private _batchPlaceId?: number;
  private _batchUniverseId?: number;
  private _batchTimeoutMs: number;
  private _reporter?: Reporter;

  // Lazy-promise state
  private _combinedBuildPromise?: Promise<CombinedBuildState>;
  private _deployPromise?: Promise<Deployment>;
  private _executionPromise?: Promise<Map<string, BatchPackageResult>>;

  // State for cleanup
  private _combinedBuildContext?: BuildContext;
  private _sharedDeployment?: Deployment;

  constructor(
    inner: JobContext,
    batchTargets: BatchTarget[],
    options?: {
      repoRoot?: string;
      batchPlaceId?: number;
      batchUniverseId?: number;
      batchTimeoutMs?: number;
      reporter?: Reporter;
    }
  ) {
    this._inner = inner;
    this._batchTargets = batchTargets;
    this._repoRoot = options?.repoRoot ?? process.cwd();
    this._batchPlaceId = options?.batchPlaceId;
    this._batchUniverseId = options?.batchUniverseId;
    this._batchTimeoutMs = options?.batchTimeoutMs ?? 300_000;
    this._reporter = options?.reporter;
  }

  async buildPlaceAsync(options: BuildPlaceOptions): Promise<BuiltPlace> {
    const buildState = await this._getCombinedBuildAsync();
    // The script content baked into BuiltPlace.target is read by
    // runSingleTestAsync but discarded in aggregated batch mode — we just
    // echo back the caller's resolved place.
    return {
      rbxlPath: buildState.rbxlPath,
      target: options.target,
    };
  }

  async deployBuiltPlaceAsync(
    options: DeployPlaceOptions
  ): Promise<Deployment> {
    const innerDeployment = await this._getSharedDeploymentAsync();

    return new BatchDeployment(options.packageName, innerDeployment);
  }

  async runScriptAsync(
    deployment: Deployment,
    options: RunScriptOptions
  ): Promise<ScriptRunResult> {
    const batchDeployment = deployment as BatchDeployment;
    const packageResults = await this._getBatchExecutionAsync();
    const result = packageResults.get(batchDeployment.packageName);

    if (!result) {
      return { success: false };
    }

    return { success: result.success, durationMs: result.durationMs };
  }

  async getLogsAsync(deployment: Deployment): Promise<string> {
    const batchDeployment = deployment as BatchDeployment;
    const packageResults = await this._getBatchExecutionAsync();
    const result = packageResults.get(batchDeployment.packageName);

    return result?.logs ?? '';
  }

  async releaseAsync(_deployment: Deployment): Promise<void> {
    // No-op — shared deployment released in disposeAsync
  }

  async releaseBuiltPlaceAsync(_builtPlace: BuiltPlace): Promise<void> {
    // No-op — combined build cleaned up in disposeAsync
  }

  async disposeAsync(): Promise<void> {
    // Release shared inner deployment
    if (this._sharedDeployment) {
      try {
        await this._inner.releaseAsync(this._sharedDeployment);
      } catch {
        // best effort
      }
    }

    // Clean up combined build context
    if (this._combinedBuildContext) {
      try {
        await this._combinedBuildContext.cleanupAsync();
      } catch {
        // best effort
      }
    }

    await this._inner.disposeAsync();
  }

  // ---- Lazy-promise internals ----

  private _getCombinedBuildAsync(): Promise<CombinedBuildState> {
    if (!this._combinedBuildPromise) {
      this._combinedBuildPromise = this._doCombinedBuildAsync();
    }
    return this._combinedBuildPromise;
  }

  private async _doCombinedBuildAsync(): Promise<CombinedBuildState> {
    OutputHelper.verbose('Building combined batch place...');

    // Set all packages to "waiting" — they're queued for building
    if (this._reporter) {
      for (const pkg of this._batchTargets) {
        this._reporter.onPackagePhaseChange(pkg.name, 'waiting');
      }
    }

    const progress: CombinedBuildProgress = {
      onPackageBuildStart: (name) => {
        this._reporter?.onPackagePhaseChange(name, 'building');
      },
      onPackageBuildComplete: (name) => {
        this._reporter?.onPackagePhaseChange(name, 'waiting');
      },
      onCombineStart: () => {
        if (this._reporter) {
          for (const pkg of this._batchTargets) {
            this._reporter.onPackagePhaseChange(pkg.name, 'combining');
          }
        }
      },
      onStepProgress: (stepProgress) => {
        if (this._reporter) {
          for (const pkg of this._batchTargets) {
            this._reporter.onPackageProgressUpdate(pkg.name, stepProgress);
          }
        }
      },
    };

    const combinedResult = await generateCombinedProjectAsync({
      batchTargets: this._batchTargets,
      repoRoot: this._repoRoot,
      batchPlaceId: this._batchPlaceId,
      batchUniverseId: this._batchUniverseId,
      progress,
    });

    this._combinedBuildContext = combinedResult.buildContext;

    return { combinedResult, rbxlPath: combinedResult.rbxlPath };
  }

  private _getSharedDeploymentAsync(): Promise<Deployment> {
    if (!this._deployPromise) {
      this._deployPromise = this._doSharedDeployAsync();
    }
    return this._deployPromise;
  }

  private async _doSharedDeployAsync(): Promise<Deployment> {
    const buildState = await this._getCombinedBuildAsync();
    const { primaryTarget } = buildState.combinedResult;

    const builtPlace: BuiltPlace = {
      rbxlPath: buildState.rbxlPath,
      target: primaryTarget,
    };

    const deployment = await this._inner.deployBuiltPlaceAsync({
      builtPlace,
      packageName: '_batch_',
      packagePath: this._repoRoot,
    });

    this._sharedDeployment = deployment;
    return deployment;
  }

  private _getBatchExecutionAsync(): Promise<Map<string, BatchPackageResult>> {
    if (!this._executionPromise) {
      this._executionPromise = this._doBatchExecutionAsync();
      // On rejection, clear the promise so that a retry re-triggers the batch
      this._executionPromise.catch(() => {
        this._executionPromise = undefined;
      });
    }
    return this._executionPromise;
  }

  private async _doBatchExecutionAsync(): Promise<
    Map<string, BatchPackageResult>
  > {
    const buildState = await this._getCombinedBuildAsync();
    const deployment = await this._getSharedDeploymentAsync();
    const { slugMap } = buildState.combinedResult;

    // Build the batch Luau script from the template
    const templatePath = resolveTemplatePath(
      import.meta.url,
      'batch-test-runner.luau'
    );
    const template = await fs.readFile(templatePath, 'utf-8');

    const slugArray = [...slugMap.values()];
    const batchScript = template.replaceAll(
      '{{ PACKAGE_SLUGS_JSON }}',
      JSON.stringify(slugArray)
    );

    OutputHelper.verbose(
      `Executing batch script for ${slugMap.size} packages (timeout: ${
        this._batchTimeoutMs / 1000
      }s)...`
    );

    const result = await this._inner.runScriptAsync(deployment, {
      scriptContent: batchScript,
      packageName: '_batch_',
      timeoutMs: this._batchTimeoutMs,
    });

    // Fetch the combined logs
    const rawLogs = await this._inner.getLogsAsync(deployment);

    if (!result.success) {
      const stateInfo = result.taskState ? ` (state: ${result.taskState})` : '';
      OutputHelper.warn(
        `Batch execution task did not complete successfully${stateInfo} — parsing partial results`
      );
      if (result.errorMessage) {
        OutputHelper.error(result.errorMessage);
      }
      if (!rawLogs || rawLogs.trim().length === 0) {
        OutputHelper.warn(
          'No logs were returned from the execution — the script may not have started'
        );
      }
      OutputHelper.verbose(`Raw batch logs:\n${rawLogs || '(empty)'}`);
    }

    // Parse into per-package results
    return parseBatchTestLogs(rawLogs, slugMap);
  }
}
