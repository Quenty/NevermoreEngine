import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type PackageResult,
  type BatchSummary,
  type IStateTracker,
} from '@quenty/cli-output-helpers/reporting';

/**
 * Minimal contract the runner needs from each work item: a name used to key
 * reporter lifecycle calls. Callers pass anything richer (a TargetPackage,
 * a multi-place deploy unit, etc.); the runner only reads `.name`.
 */
export interface BatchItem {
  name: string;
}

/** Partial result returned by executeAsync — durationMs is optional. */
export type PartialBatchResult<TResult extends PackageResult> = Omit<
  TResult,
  'durationMs'
> & {
  /**
   * Inner-measured duration. When provided, overrides the outer wall-clock
   * timing (useful in aggregated batch mode where every package's outer
   * await resolves at the same instant).
   */
  durationMs?: number;
};

export interface BatchOptions<
  TItem extends BatchItem,
  TResult extends PackageResult,
> {
  items: TItem[];
  concurrency?: number;
  reporter: Reporter;
  bufferOutput?: boolean;
  stateTracker?: IStateTracker;
  executeAsync: (
    item: TItem,
    reporter: Reporter
  ) => Promise<PartialBatchResult<TResult>>;
}

export async function runBatchAsync<
  TItem extends BatchItem,
  TResult extends PackageResult,
>(options: BatchOptions<TItem, TResult>): Promise<BatchSummary<TResult>> {
  const {
    items,
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
      while (runningCount < concurrency && nextIndex < items.length) {
        const item = items[nextIndex++]!;
        runningCount++;

        _runOneAsync<TItem, TResult>(
          item,
          executeAsync,
          reporter,
          bufferOutput,
          stateTracker
        )
          .then((result) => {
            results.push(result);
          })
          .finally(() => {
            runningCount--;
            if (nextIndex >= items.length && runningCount === 0) {
              resolveAll();
            } else {
              tryStartNext();
            }
          });
      }

      if (items.length === 0) {
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

async function _runOneAsync<
  TItem extends BatchItem,
  TResult extends PackageResult,
>(
  item: TItem,
  executeAsync: (
    item: TItem,
    reporter: Reporter
  ) => Promise<PartialBatchResult<TResult>>,
  reporter: Reporter,
  bufferOutput: boolean,
  stateTracker?: IStateTracker
): Promise<TResult> {
  reporter.onPackageStart(item.name);
  const startMs = Date.now();

  const execute = async (): Promise<TResult> => {
    try {
      const partial = await executeAsync(item, reporter);
      const durationMs = partial.durationMs ?? Date.now() - startMs;
      return { ...partial, durationMs } as TResult;
    } catch (err) {
      const errorMessage = OutputHelper.formatErrorChain(err);
      const currentPhase = stateTracker?.getCurrentPhase(item.name);
      const failedPhase =
        currentPhase &&
        currentPhase !== 'pending' &&
        currentPhase !== 'passed' &&
        currentPhase !== 'failed'
          ? currentPhase
          : undefined;
      return {
        packageName: item.name,
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
