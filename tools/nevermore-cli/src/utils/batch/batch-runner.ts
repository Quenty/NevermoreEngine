import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type PackageResult,
  type BatchSummary,
  type IStateTracker,
} from '@quenty/cli-output-helpers/reporting';
import { type TargetPackage } from './changed-packages-utils.js';

export interface BatchOptions<TResult extends PackageResult> {
  packages: TargetPackage[];
  concurrency?: number;
  reporter: Reporter;
  bufferOutput?: boolean;
  stateTracker?: IStateTracker;
  executeAsync: (
    pkg: TargetPackage,
    reporter: Reporter
  ) => Promise<Omit<TResult, 'durationMs'>>;
}

export async function runBatchAsync<TResult extends PackageResult>(
  options: BatchOptions<TResult>
): Promise<BatchSummary<TResult>> {
  const {
    packages,
    concurrency = Infinity,
    reporter,
    bufferOutput = false,
    stateTracker,
    executeAsync,
  } = options;

  const results: TResult[] = [];
  let runningCount = 0;
  let nextIndex = 0;
  const startTimeMs = Date.now();

  await new Promise<void>((resolveAll) => {
    function tryStartNext(): void {
      while (runningCount < concurrency && nextIndex < packages.length) {
        const pkg = packages[nextIndex++];
        runningCount++;

        _runOneAsync<TResult>(pkg, executeAsync, reporter, bufferOutput, stateTracker)
          .then((result) => {
            results.push(result);
          })
          .finally(() => {
            runningCount--;
            if (nextIndex >= packages.length && runningCount === 0) {
              resolveAll();
            } else {
              tryStartNext();
            }
          });
      }

      if (packages.length === 0) {
        resolveAll();
      }
    }

    tryStartNext();
  });

  const passed = results.filter((r) => r.success).length;
  const failed = results.filter((r) => !r.success).length;
  const durationMs = Date.now() - startTimeMs;

  return {
    packages: results,
    summary: { total: results.length, passed, failed, durationMs },
  };
}

async function _runOneAsync<TResult extends PackageResult>(
  pkg: TargetPackage,
  executeAsync: (
    pkg: TargetPackage,
    reporter: Reporter
  ) => Promise<Omit<TResult, 'durationMs'>>,
  reporter: Reporter,
  bufferOutput: boolean,
  stateTracker?: IStateTracker
): Promise<TResult> {
  reporter.onPackageStart(pkg.name);
  const startMs = Date.now();

  const execute = async (): Promise<TResult> => {
    try {
      const partial = await executeAsync(pkg, reporter);
      return { ...partial, durationMs: Date.now() - startMs } as TResult;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      const currentPhase = stateTracker?.getCurrentPhase(pkg.name);
      const failedPhase =
        currentPhase && currentPhase !== 'pending' && currentPhase !== 'passed' && currentPhase !== 'failed'
          ? currentPhase
          : undefined;
      return {
        packageName: pkg.name,
        success: false,
        logs: '',
        durationMs: Date.now() - startMs,
        error: errorMessage,
        failedPhase,
      } as TResult;
    }
  };

  let result: TResult;
  let bufferedOutput: string[] | undefined;

  if (bufferOutput) {
    const buffered = await OutputHelper.runBuffered(execute);
    result = buffered.result;
    bufferedOutput = buffered.output;
  } else {
    result = await execute();
  }

  reporter.onPackageResult(result, bufferedOutput);
  return result;
}
