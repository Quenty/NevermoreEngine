import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { isCI, readPackageNameAsync } from '../../utils/nevermore-cli-utils.js';
import { createBasePlaceResolver } from '../../utils/build/base-place-resolver-factory.js';
import {
  CloudJobContext,
  LocalJobContext,
} from '../../utils/job-context/index.js';
import { runSingleTestAsync } from '../../utils/testing/runner/test-runner.js';
import {
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveSingleDeployTarget,
} from '@quenty/nevermore-deploy-config';
import {
  type Reporter,
  type LiveStateTracker,
  CompositeReporter,
  GithubCommentTableReporter,
  JsonFileReporter,
  SimpleReporter,
  SpinnerReporter,
  createTestCommentConfig,
} from '../../utils/testing/reporting/index.js';

export interface TestProjectArgs extends NevermoreGlobalArgs {
  cloud?: boolean;
  apiKey?: string;
  logs?: boolean;
  universeId?: number;
  placeId?: number;
  scriptTemplate?: string;
  scriptText?: string;
  output?: string;
  timeout?: number;
}

export class TestProjectCommand<T>
  implements CommandModule<T, TestProjectArgs>
{
  public command = 'test';
  public describe = 'Run tests for a single package';

  public builder = (args: Argv<T>) => {
    args.option('cloud', {
      describe: 'Run tests via Open Cloud instead of locally',
      type: 'boolean',
      default: false,
    });
    args.option('api-key', {
      describe: 'Roblox Open Cloud API key (--cloud only)',
      type: 'string',
    });
    args.option('logs', {
      describe:
        'Show execution logs. Defaults on with --script-text, whose output is the whole point of the run',
      type: 'boolean',
    });
    args.option('universe-id', {
      describe:
        'Override universe ID from deploy.nevermore.json (--cloud only)',
      type: 'number',
    });
    args.option('place-id', {
      describe: 'Override place ID from deploy.nevermore.json (--cloud only)',
      type: 'number',
    });
    args.option('script-template', {
      describe: 'Override script template path from deploy.nevermore.json',
      type: 'string',
    });
    args.option('script-text', {
      describe:
        'Luau code to execute directly instead of the configured script template',
      type: 'string',
    });
    args.option('output', {
      describe: 'Write JSON results to this file',
      type: 'string',
    });
    args.option('timeout', {
      describe:
        'Max script execution time in seconds. Sent to the Open Cloud API so Roblox cancels server-side on overrun. Max 300s (API limit). (default: 300)',
      type: 'number',
    });

    return args as Argv<TestProjectArgs>;
  };

  public handler = async (args: TestProjectArgs) => {
    const cwd = process.cwd();
    const packageName = (await readPackageNameAsync(cwd)) ?? path.basename(cwd);
    // A probe run exists to show its output. Hiding it behind an opt-in flag
    // made --script-text look broken enough that a workaround was written into
    // the docs instead of a bug report.
    const showLogs = args.logs ?? args.scriptText !== undefined;
    const useSpinner = process.stdout.isTTY && !args.verbose;

    const reporter = new CompositeReporter(
      [packageName],
      (state: LiveStateTracker) => {
        const reporters: Reporter[] = [
          useSpinner
            ? new SpinnerReporter(state, {
                showLogs,
                actionVerb: 'Testing',
              })
            : new SimpleReporter(state, {
                alwaysShowLogs: showLogs,
                verbose: args.verbose,
                successMessage: 'Tests passed!',
                failureMessage:
                  'Tests failed! See output above for more information.',
              }),
        ];
        if (args.output) {
          reporters.push(new JsonFileReporter(state, args.output));
        }
        if (isCI()) {
          reporters.push(
            new GithubCommentTableReporter(state, createTestCommentConfig(), 1)
          );
        }
        return reporters;
      }
    );
    await reporter.startAsync();

    let exitCode = 0;
    try {
      const config = await loadDeployConfigAsync(resolveDeployConfigPath(cwd));
      const target = resolveSingleDeployTarget(
        config,
        'test',
        'nevermore batch test'
      );

      // A local run needs Open Cloud only to fetch a base place. The key is
      // resolved lazily so a package without one is never asked for credentials.
      const client = args.cloud
        ? new OpenCloudClient({
            apiKey: await getApiKeyAsync(args),
            rateLimiter: new RateLimiter(),
          })
        : new OpenCloudClient({
            apiKey: () => getApiKeyAsync(args),
            rateLimiter: new RateLimiter(),
          });
      const basePlaceResolver = createBasePlaceResolver(client, args);

      const context = args.cloud
        ? new CloudJobContext(reporter, client, basePlaceResolver)
        : new LocalJobContext(reporter, client, basePlaceResolver);

      let result;
      try {
        result = await runSingleTestAsync(context, {
          packagePath: cwd,
          packageName,
          target,
          scriptText: args.scriptText,
          timeoutMs:
            args.timeout !== undefined ? args.timeout * 1000 : undefined,
        });
      } finally {
        await context.disposeAsync();
      }

      reporter.onPackageResult({
        packageName,
        success: result.success,
        logs: result.logs,
        durationMs: 0,
        progressSummary: result.testCounts
          ? { kind: 'test-counts', ...result.testCounts }
          : undefined,
      });
      if (!result.success) exitCode = 1;
    } catch (err) {
      reporter.onPackageResult({
        packageName,
        success: false,
        logs: '',
        durationMs: 0,
        error: OutputHelper.formatErrorChain(err),
      });
      exitCode = 1;
    }

    await reporter.stopAsync();
    process.exit(exitCode);
  };
}
