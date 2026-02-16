import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '../../utils/auth/credential-store.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { readPackageNameAsync } from '../../utils/nevermore-cli-utils.js';
import {
  runSingleCloudTestAsync,
  runSingleLocalTestAsync,
} from '../../utils/testing/runner/test-runner.js';
import {
  type LiveStateTracker,
  CompositeReporter,
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

    return args as Argv<TestProjectArgs>;
  };

  public handler = async (args: TestProjectArgs) => {
    try {
      const cwd = process.cwd();
      const packageName =
        (await readPackageNameAsync(cwd)) ?? path.basename(cwd);
      const showLogs = args.logs ?? false;
      const useSpinner = process.stdout.isTTY && !args.verbose;

      const reporter = new CompositeReporter([packageName], (state: LiveStateTracker) => [
        useSpinner
          ? new SpinnerReporter(state, {
              showLogs,
              actionVerb: 'Testing',
            })
          : new SimpleReporter(state, {
              alwaysShowLogs: showLogs,
              successMessage: 'Tests passed!',
              failureMessage: 'Tests failed! See output above for more information.',
            }),
      ]);
      await reporter.startAsync();

      const scriptText = args.scriptText;

      let result;
      if (args.cloud) {
        const apiKey = await getApiKeyAsync(args);
        const client = new OpenCloudClient({
          apiKey,
          rateLimiter: new RateLimiter(),
        });
        result = await runSingleCloudTestAsync({
          packagePath: cwd,
          client,
          reporter,
          packageName,
          scriptText,
        });
      } else {
        result = await runSingleLocalTestAsync({
          packagePath: cwd,
          reporter,
          packageName,
          scriptText,
        });
      }

      reporter.onPackageResult({
        packageName,
        success: result.success,
        logs: result.logs,
        durationMs: 0,
      });

      await reporter.stopAsync();
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }

    process.exit(0);
  };
}
