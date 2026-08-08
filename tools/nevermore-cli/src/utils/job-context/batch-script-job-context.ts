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
  private _chunkSize: number;
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
      chunkSize?: number;
      reporter?: Reporter;
    }
  ) {
    this._inner = inner;
    this._batchTargets = batchTargets;
    this._repoRoot = options?.repoRoot ?? process.cwd();
    this._batchPlaceId = options?.batchPlaceId;
    this._batchUniverseId = options?.batchUniverseId;
    this._batchTimeoutMs = options?.batchTimeoutMs ?? 300_000;
    // 16 keeps a chunk's log well inside the retained window: 8 packages came
    // back at 65KB intact, while 73 at 272KB lost its first 14.
    this._chunkSize = options?.chunkSize ?? 16;
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

    return {
      success: result.success,
      durationMs: result.durationMs,
      errorMessage: result.error,
    };
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

    // Run in chunks. Open Cloud keeps only the tail of a task's log, so one
    // task covering every package loses the packages that ran first — measured
    // at 73 packages, the first 14 came back unreadable. Chunking keeps each
    // task's output inside the window, and gives each its own execution budget
    // instead of sharing one 300s ceiling.
    const chunks = chunkSlugMap(slugMap, this._chunkSize);
    const merged = new Map<string, BatchPackageResult>();

    if (chunks.length > 1) {
      OutputHelper.verbose(
        `Executing ${slugMap.size} packages in ${chunks.length} chunks of up to ${this._chunkSize}`
      );
    }

    for (const [index, chunk] of chunks.entries()) {
      const label =
        chunks.length > 1 ? ` (chunk ${index + 1}/${chunks.length})` : '';
      const batchScript = template.replaceAll(
        '{{ PACKAGE_SLUGS_JSON }}',
        JSON.stringify([...chunk.values()])
      );

      OutputHelper.verbose(
        `Executing batch script for ${chunk.size} packages${label} (timeout: ${
          this._batchTimeoutMs / 1000
        }s)...`
      );

      const result = await this._inner.runScriptAsync(deployment, {
        scriptContent: batchScript,
        packageName: '_batch_',
        timeoutMs: this._batchTimeoutMs,
      });

      const rawLogs = await this._inner.getLogsAsync(deployment);

      if (!result.success) {
        const stateInfo = result.taskState
          ? ` (state: ${result.taskState})`
          : '';
        OutputHelper.warn(
          `Batch execution task${label} did not complete successfully${stateInfo} — parsing partial results`
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

      for (const [packageName, packageResult] of parseBatchTestLogs(
        rawLogs,
        chunk
      )) {
        merged.set(packageName, packageResult);
      }
    }

    return merged;
  }
}

/**
 * Split the package map into chunks small enough for one task's log to survive.
 *
 * Sized by package count rather than bytes because output volume is not known
 * until the run happens, and the retained window is not a fixed size either.
 */
export function chunkSlugMap(
  slugMap: Map<string, string>,
  chunkSize: number
): Map<string, string>[] {
  const entries = [...slugMap.entries()];
  if (chunkSize <= 0 || entries.length <= chunkSize) {
    return [slugMap];
  }

  const chunks: Map<string, string>[] = [];
  for (let i = 0; i < entries.length; i += chunkSize) {
    chunks.push(new Map(entries.slice(i, i + chunkSize)));
  }
  return chunks;
}
