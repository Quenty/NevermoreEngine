import { OutputHelper } from '@quenty/cli-output-helpers';
import { OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { RateLimiter } from '../open-cloud/rate-limiter.js';
import { TestablePackage } from './changed-tests-utils.js';
import { runSingleTestAsync, SingleTestResult, type TestPhase } from './test-runner.js';

export type { TestPhase };

export interface BatchTestResult {
  packageName: string;
  placeId: number;
  success: boolean;
  logs: string;
  durationMs: number;
  error?: string;
}

export interface BatchTestSummary {
  packages: BatchTestResult[];
  summary: {
    total: number;
    passed: number;
    failed: number;
    durationMs: number;
  };
}

export interface BatchTestCallbacks {
  onPackageStart?: (pkg: TestablePackage) => void;
  onPackagePhaseChange?: (packageName: string, phase: TestPhase) => void;
  onPackageResult?: (result: BatchTestResult, bufferedOutput?: string[]) => void;
  onProgress?: (completed: number, total: number, elapsedMs: number) => void;
}

export interface BatchTestOptions {
  packages: TestablePackage[];
  apiKey: string;
  concurrency?: number;
  timeoutMs?: number;
  callbacks?: BatchTestCallbacks;
  bufferOutput?: boolean;
}

/**
 * Run tests for multiple packages with concurrency control.
 * All packages share a single RateLimiter and API key.
 */
export async function runBatchTestsAsync(
  options: BatchTestOptions
): Promise<BatchTestSummary> {
  const {
    packages,
    apiKey,
    concurrency = 3,
    timeoutMs = 120_000,
    callbacks = {},
    bufferOutput = false,
  } = options;

  const rateLimiter = new RateLimiter();
  const client = new OpenCloudClient({ apiKey, rateLimiter });

  const total = packages.length;
  const results: BatchTestResult[] = [];
  let completedCount = 0;
  let runningCount = 0;
  let nextIndex = 0;
  const startTimeMs = Date.now();

  await new Promise<void>((resolveAll) => {
    function tryStartNext(): void {
      while (runningCount < concurrency && nextIndex < packages.length) {
        const pkg = packages[nextIndex++];
        runningCount++;

        _runOneAsync(pkg, client, timeoutMs, callbacks, bufferOutput)
          .then((result) => {
            results.push(result);
            completedCount++;
            callbacks.onProgress?.(completedCount, total, Date.now() - startTimeMs);
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
  client: OpenCloudClient,
  timeoutMs: number,
  callbacks: BatchTestCallbacks,
  bufferOutput: boolean
): Promise<BatchTestResult> {
  callbacks.onPackageStart?.(pkg);

  const startMs = Date.now();

  const onPhaseChange = callbacks.onPackagePhaseChange
    ? (phase: TestPhase) => callbacks.onPackagePhaseChange!(pkg.name, phase)
    : undefined;

  const execute = async (): Promise<{ batchResult: BatchTestResult; output?: string[] }> => {
    try {
      const result = await _runWithRetryAsync(pkg, client, timeoutMs, onPhaseChange);
      const durationMs = Date.now() - startMs;

      return {
        batchResult: {
          packageName: pkg.name,
          placeId: result.placeId,
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

  callbacks.onPackageResult?.(batchResult, bufferedOutput);
  return batchResult;
}

/**
 * Run a test with a single retry on transient failure.
 */
async function _runWithRetryAsync(
  pkg: TestablePackage,
  client: OpenCloudClient,
  timeoutMs: number,
  onPhaseChange?: (phase: TestPhase) => void
): Promise<SingleTestResult> {
  try {
    return await runSingleTestAsync(pkg.path, client, timeoutMs, onPhaseChange);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);

    // Only retry on transient failures (timeouts, network errors)
    if (message.includes('timed out') || message.includes('fetch failed')) {
      OutputHelper.warn(`${pkg.name}: transient failure, retrying...`);
      return await runSingleTestAsync(pkg.path, client, timeoutMs, onPhaseChange);
    }

    throw err;
  }
}
