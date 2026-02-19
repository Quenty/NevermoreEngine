import * as fs from 'fs/promises';
import * as path from 'path';
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
import {
  type DeployTarget,
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveDeployTarget,
} from '../build/deploy-config.js';
import { type TargetPackage } from '../batch/changed-packages-utils.js';
import {
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
  private _packages: TargetPackage[];
  private _repoRoot: string;
  private _batchPlaceId?: number;
  private _batchUniverseId?: number;
  private _perPackageTimeoutMs: number;

  // Lazy-promise state
  private _combinedBuildPromise?: Promise<CombinedBuildState>;
  private _deployPromise?: Promise<Deployment>;
  private _executionPromise?: Promise<Map<string, BatchPackageResult>>;
  private _packageTargets = new Map<string, DeployTarget>();

  // State for cleanup
  private _combinedBuildContext?: BuildContext;
  private _sharedDeployment?: Deployment;

  constructor(
    inner: JobContext,
    packages: TargetPackage[],
    options?: {
      repoRoot?: string;
      batchPlaceId?: number;
      batchUniverseId?: number;
      perPackageTimeoutMs?: number;
    }
  ) {
    this._inner = inner;
    this._packages = packages;
    this._repoRoot = options?.repoRoot ?? process.cwd();
    this._batchPlaceId = options?.batchPlaceId;
    this._batchUniverseId = options?.batchUniverseId;
    this._perPackageTimeoutMs = options?.perPackageTimeoutMs ?? 120_000;
  }

  async buildPlaceAsync(options: BuildPlaceOptions): Promise<BuiltPlace> {
    const buildState = await this._getCombinedBuildAsync();
    const packageName =
      options.packageName ?? path.basename(options.packagePath ?? '');

    // Load per-package target for the BuiltPlace.target field
    // (runSingleTestAsync reads scriptTemplate from it, but we ignore the script content)
    let target = this._packageTargets.get(packageName);
    if (!target) {
      const packagePath = options.packagePath ?? process.cwd();
      const configPath = resolveDeployConfigPath(packagePath);
      const config = await loadDeployConfigAsync(configPath);
      target = resolveDeployTarget(config, options.targetName);
      this._packageTargets.set(packageName, target);
    }

    return {
      rbxlPath: buildState.rbxlPath,
      target,
    };
  }

  async deployBuiltPlaceAsync(
    reporter: Reporter,
    options: DeployPlaceOptions
  ): Promise<Deployment> {
    const innerDeployment = await this._getSharedDeploymentAsync(reporter);

    return new BatchDeployment(options.packageName, innerDeployment);
  }

  async runScriptAsync(
    deployment: Deployment,
    _reporter: Reporter,
    options: RunScriptOptions
  ): Promise<ScriptRunResult> {
    const batchDeployment = deployment as BatchDeployment;
    const packageResults = await this._getBatchExecutionAsync();
    const result = packageResults.get(batchDeployment.packageName);

    if (!result) {
      return { success: false };
    }

    return { success: result.success };
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

    const combinedResult = await generateCombinedProjectAsync({
      packages: this._packages,
      repoRoot: this._repoRoot,
      batchPlaceId: this._batchPlaceId,
      batchUniverseId: this._batchUniverseId,
    });

    this._combinedBuildContext = combinedResult.buildContext;

    return { combinedResult, rbxlPath: combinedResult.rbxlPath };
  }

  private _getSharedDeploymentAsync(reporter?: Reporter): Promise<Deployment> {
    if (!this._deployPromise) {
      this._deployPromise = this._doSharedDeployAsync(reporter);
    }
    return this._deployPromise;
  }

  private async _doSharedDeployAsync(reporter?: Reporter): Promise<Deployment> {
    const buildState = await this._getCombinedBuildAsync();
    const { primaryTarget } = buildState.combinedResult;

    // Create a minimal reporter that doesn't emit per-package phases
    const batchReporter = reporter ?? _noopReporter();

    const builtPlace: BuiltPlace = {
      rbxlPath: buildState.rbxlPath,
      target: primaryTarget,
    };

    const deployment = await this._inner.deployBuiltPlaceAsync(batchReporter, {
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

    const totalTimeoutMs = this._packages.length * this._perPackageTimeoutMs;

    OutputHelper.verbose(
      `Executing batch script for ${slugMap.size} packages (timeout: ${
        totalTimeoutMs / 1000
      }s)...`
    );

    const result = await this._inner.runScriptAsync(
      deployment,
      _noopReporter(),
      {
        scriptContent: batchScript,
        packageName: '_batch_',
        timeoutMs: totalTimeoutMs,
      }
    );

    // Fetch the combined logs
    const rawLogs = await this._inner.getLogsAsync(deployment);

    if (!result.success) {
      OutputHelper.warn(
        'Batch execution task did not complete successfully — parsing partial results'
      );
      OutputHelper.verbose(`Raw batch logs:\n${rawLogs || '(empty)'}`);
    }

    // Parse into per-package results
    return parseBatchTestLogs(rawLogs, slugMap);
  }
}

function _noopReporter(): Reporter {
  return {
    onPackageStart: () => {},
    onPackagePhaseChange: () => {},
    onPackageResult: () => {},
    startAsync: async () => {},
    stopAsync: async () => {},
  };
}
