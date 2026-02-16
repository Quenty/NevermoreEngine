import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type PackageResult,
  type BatchSummary,
} from '@quenty/cli-output-helpers/reporting';
import { OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { type TargetPackage } from '../testing/changed-tests-utils.js';
import { buildPlaceAsync } from '../build/build.js';
import { uploadPlaceAsync } from '../build/upload.js';

export interface BatchDeployOptions {
  packages: TargetPackage[];
  client: OpenCloudClient;
  apiKey: string;
  targetName: string;
  concurrency?: number;
  reporter: Reporter;
  bufferOutput?: boolean;
  publish?: boolean;
}

/**
 * Deploy multiple packages with concurrency control.
 * Each package is built via rojo then uploaded via Open Cloud.
 */
export async function runBatchDeployAsync(
  options: BatchDeployOptions
): Promise<BatchSummary> {
  const {
    packages,
    client,
    apiKey,
    targetName,
    concurrency = 3,
    reporter,
    bufferOutput = false,
    publish = false,
  } = options;

  const results: PackageResult[] = [];
  let runningCount = 0;
  let nextIndex = 0;
  const startTimeMs = Date.now();

  await new Promise<void>((resolveAll) => {
    function tryStartNext(): void {
      while (runningCount < concurrency && nextIndex < packages.length) {
        const pkg = packages[nextIndex++];
        runningCount++;

        _runOneAsync(pkg, client, apiKey, targetName, reporter, bufferOutput, publish)
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
  pkg: TargetPackage,
  client: OpenCloudClient,
  apiKey: string,
  targetName: string,
  reporter: Reporter,
  bufferOutput: boolean,
  publish: boolean
): Promise<PackageResult> {
  reporter.onPackageStart(pkg.name);

  const startMs = Date.now();

  const execute = async (): Promise<{
    result: PackageResult;
    output?: string[];
  }> => {
    try {
      const buildResult = await buildPlaceAsync({
        targetName,
        outputFileName: publish ? 'publish.rbxl' : 'deploy.rbxl',
        packagePath: pkg.path,
        reporter,
        packageName: pkg.name,
      });

      const { version } = await uploadPlaceAsync({
        buildResult,
        args: { apiKey, publish },
        client,
        reporter,
        packageName: pkg.name,
      });

      const durationMs = Date.now() - startMs;
      const action = publish ? 'Published' : 'Saved';
      return {
        result: {
          packageName: pkg.name,
          success: true,
          logs: `${action} v${version}`,
          durationMs,
        },
      };
    } catch (err) {
      const durationMs = Date.now() - startMs;
      const errorMessage = err instanceof Error ? err.message : String(err);

      return {
        result: {
          packageName: pkg.name,
          success: false,
          logs: '',
          durationMs,
          error: errorMessage,
        },
      };
    }
  };

  let packageResult: PackageResult;
  let bufferedOutput: string[] | undefined;

  if (bufferOutput) {
    const { result, output } = await OutputHelper.runBuffered(execute);
    packageResult = result.result;
    bufferedOutput = output;
  } else {
    const result = await execute();
    packageResult = result.result;
  }

  reporter.onPackageResult(packageResult, bufferedOutput);
  return packageResult;
}
