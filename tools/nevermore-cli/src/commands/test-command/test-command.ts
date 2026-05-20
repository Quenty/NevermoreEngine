import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { readPackageNameAsync } from '../../utils/nevermore-cli-utils.js';
import {
  CloudJobContext,
  LocalJobContext,
} from '../../utils/job-context/index.js';
import { runSingleTestAsync } from '../../utils/testing/runner/test-runner.js';
import {
  type Reporter,
  type LiveStateTracker,
  CompositeReporter,
  JsonFileReporter,
  SimpleReporter,
  SpinnerReporter,
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
      describe: 'Show execution logs',
      type: 'boolean',
      default: false,
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
        'Max script execution time in seconds. Sent to the Open Cloud API so Roblox cancels server-side on overrun (default: 120)',
      type: 'number',
    });

    return args as Argv<TestProjectArgs>;
  };

  public handler = async (args: TestProjectArgs) => {
    const cwd = process.cwd();
    const packageName = (await readPackageNameAsync(cwd)) ?? path.basename(cwd);
    const showLogs = args.logs ?? false;
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
        return reporters;
      }
    );
    await reporter.startAsync();

    let exitCode = 0;
    try {
      const context = args.cloud
        ? new CloudJobContext(
            reporter,
            new OpenCloudClient({
              apiKey: await getApiKeyAsync(args),
              rateLimiter: new RateLimiter(),
            })
          )
        : new LocalJobContext(reporter);

      let result;
      try {
        result = await runSingleTestAsync(context, {
          packagePath: cwd,
          packageName,
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
