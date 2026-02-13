import { OutputHelper } from '@quenty/cli-output-helpers';
import { OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { RateLimiter } from '../open-cloud/rate-limiter.js';
import { TestablePackage } from './changed-tests-utils.js';
import { runSingleTestAsync, SingleTestResult } from './test-runner.js';

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
  onPackageResult?: (result: BatchTestResult) => void;
  onProgress?: (completed: number, total: number, elapsedMs: number) => void;
}

export interface BatchTestOptions {
  packages: TestablePackage[];
  apiKey: string;
  concurrency?: number;
  timeoutMs?: number;
  callbacks?: BatchTestCallbacks;
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

        _runOneAsync(pkg, client, timeoutMs, callbacks)
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
  callbacks: BatchTestCallbacks
): Promise<BatchTestResult> {
  callbacks.onPackageStart?.(pkg);

  const startMs = Date.now();

  try {
    const result = await _runWithRetryAsync(pkg, client, timeoutMs);
    const durationMs = Date.now() - startMs;

    const batchResult: BatchTestResult = {
      packageName: pkg.name,
      placeId: result.placeId,
      success: result.success,
      logs: result.logs,
      durationMs,
    };

    callbacks.onPackageResult?.(batchResult);
    return batchResult;
  } catch (err) {
    const durationMs = Date.now() - startMs;
    const errorMessage = err instanceof Error ? err.message : String(err);

    const batchResult: BatchTestResult = {
      packageName: pkg.name,
      placeId: pkg.target.placeId,
      success: false,
      logs: '',
      durationMs,
      error: errorMessage,
    };

    callbacks.onPackageResult?.(batchResult);
    return batchResult;
  }
}

/**
 * Run a test with a single retry on transient failure.
 */
async function _runWithRetryAsync(
  pkg: TestablePackage,
  client: OpenCloudClient,
  timeoutMs: number
): Promise<SingleTestResult> {
  try {
    return await runSingleTestAsync(pkg.path, client, timeoutMs);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);

    // Only retry on transient failures (timeouts, network errors)
    if (message.includes('timed out') || message.includes('fetch failed')) {
      OutputHelper.warn(`${pkg.name}: transient failure, retrying...`);
      return await runSingleTestAsync(pkg.path, client, timeoutMs);
    }

    throw err;
  }
}
