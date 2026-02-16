import { OutputHelper } from '@quenty/cli-output-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { OpenCloudClient } from '../../open-cloud/open-cloud-client.js';
import { TestablePackage } from '../changed-tests-utils.js';
import {
  runSingleCloudTestAsync,
  runSingleLocalTestAsync,
  type SingleTestResult,
} from './test-runner.js';
import {
  type BatchTestResult,
  type BatchTestSummary,
} from '../reporting/test-types.js';

export type { TestPhase } from './test-runner.js';
export type { BatchTestResult, BatchTestSummary } from '../reporting/test-types.js';

export interface BatchTestOptions {
  packages: TestablePackage[];
  client?: OpenCloudClient;
  concurrency?: number;
  timeoutMs?: number;
  reporter: Reporter;
  bufferOutput?: boolean;
}

/**
 * Run tests for multiple packages with concurrency control.
 * When a client is provided, tests run via Open Cloud; otherwise locally.
 */
export async function runBatchTestsAsync(
  options: BatchTestOptions
): Promise<BatchTestSummary> {
  const {
    packages,
    client,
    concurrency = 3,
    timeoutMs = 120_000,
    reporter,
    bufferOutput = false,
  } = options;

  const results: BatchTestResult[] = [];
  let runningCount = 0;
  let nextIndex = 0;
  const startTimeMs = Date.now();

  await new Promise<void>((resolveAll) => {
    function tryStartNext(): void {
      while (runningCount < concurrency && nextIndex < packages.length) {
        const pkg = packages[nextIndex++];
        runningCount++;

        _runOneAsync(pkg, client, timeoutMs, reporter, bufferOutput)
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
    summary: {
      total: results.length,
      passed,
      failed,
      durationMs,
    },
  };
}

async function _runOneAsync(
  pkg: TestablePackage,
  client: OpenCloudClient | undefined,
  timeoutMs: number,
  reporter: Reporter,
  bufferOutput: boolean
): Promise<BatchTestResult> {
  reporter.onPackageStart(pkg.name);

  const startMs = Date.now();

  const execute = async (): Promise<{
    batchResult: BatchTestResult;
    output?: string[];
  }> => {
    try {
      const result = client
        ? await _runWithRetryAsync(pkg, client, timeoutMs, reporter)
        : await runSingleLocalTestAsync({
            packagePath: pkg.path,
            reporter,
            packageName: pkg.name,
            timeoutMs,
          });
      const durationMs = Date.now() - startMs;

      return {
        batchResult: {
          packageName: pkg.name,
          placeId: pkg.target.placeId,
          success: result.success,
          logs: result.logs,
          durationMs,
        },
      };
    } catch (err) {
      const durationMs = Date.now() - startMs;
      const errorMessage = err instanceof Error ? err.message : String(err);

      return {
        batchResult: {
          packageName: pkg.name,
          placeId: pkg.target.placeId,
          success: false,
          logs: '',
          durationMs,
          error: errorMessage,
        },
      };
    }
  };

  let batchResult: BatchTestResult;
  let bufferedOutput: string[] | undefined;

  if (bufferOutput) {
    const { result, output } = await OutputHelper.runBuffered(execute);
    batchResult = result.batchResult;
    bufferedOutput = output;
  } else {
    const result = await execute();
    batchResult = result.batchResult;
  }

  reporter.onPackageResult(batchResult, bufferedOutput);
  return batchResult;
}

/**
 * Run a test with a single retry on transient failure.
 */
async function _runWithRetryAsync(
  pkg: TestablePackage,
  client: OpenCloudClient,
  timeoutMs: number,
  reporter: Reporter
): Promise<SingleTestResult> {
  const opts = {
    packagePath: pkg.path,
    client,
    reporter,
    packageName: pkg.name,
    timeoutMs,
  };

  try {
    return await runSingleCloudTestAsync(opts);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);

    // Only retry on transient failures (timeouts, network errors)
    if (message.includes('timed out') || message.includes('fetch failed')) {
      OutputHelper.warn(`${pkg.name}: transient failure, retrying...`);
      return await runSingleCloudTestAsync(opts);
    }

    throw err;
  }
}
