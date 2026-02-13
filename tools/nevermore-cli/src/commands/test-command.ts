import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import { buildAndUploadAsync } from '../utils/build/build-and-upload.js';
import { tryRenamePlaceAsync } from '../utils/auth/roblox-auth/index.js';
import { buildPlaceNameAsync } from '../utils/nevermore-cli-utils.js';
import { readTestScriptAsync } from '../utils/testing/test-runner.js';

export interface TestProjectArgs extends NevermoreGlobalArgs {
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
  public describe = 'Build, deploy, and run tests via Roblox Open Cloud';

  public builder = (args: Argv<T>) => {
    args.option('api-key', {
      describe: 'Roblox Open Cloud API key',
      type: 'string',
    });
    args.option('logs', {
      describe: 'Show Open Cloud execution logs',
      type: 'boolean',
      default: false,
    });
    args.option('universe-id', {
      describe: 'Override universe ID from deploy.nevermore.json',
      type: 'number',
    });
    args.option('place-id', {
      describe: 'Override place ID from deploy.nevermore.json',
      type: 'number',
    });
    args.option('script-template', {
      describe: 'Override script template path from deploy.nevermore.json',
      type: 'string',
    });
    args.option('script-text', {
      describe: 'Luau code to execute directly (instead of a script file)',
      type: 'string',
    });

    return args as Argv<TestProjectArgs>;
  };

  public handler = async (args: TestProjectArgs) => {
    try {
      await this._runAsync(args);
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };

  private _runAsync = async (args: TestProjectArgs) => {
    if (args.scriptText) {
      // --script-text mode: build, upload, then run custom script
      await this._runWithScriptTextAsync(args);
    } else {
      // Standard mode: use the shared test runner
      await this._runStandardTestAsync(args);
    }
  };

  /**
   * Standard test: delegates to runSingleTestAsync which handles the full
   * build → upload → execute → poll → logs pipeline.
   */
  private _runStandardTestAsync = async (args: TestProjectArgs) => {
    const buildResult = await buildAndUploadAsync(args, 'test', 'test.rbxl');
    if (!buildResult) {
      OutputHelper.info(
        '[DRYRUN] Would build, upload, execute script, and report results'
      );
      return;
    }

    const { client, target, version, packagePath } = buildResult;

    // Rename place to reflect current package + commit
    const placeName = await buildPlaceNameAsync(packagePath);
    await tryRenamePlaceAsync(target.placeId, placeName);

    // Read and execute the test script
    const scriptContent = await readTestScriptAsync(packagePath, target.scriptTemplate);

    OutputHelper.info('Running script via Open Cloud...');

    const task = await client.createExecutionTaskAsync(
      target.universeId,
      target.placeId,
      version,
      scriptContent
    );

    const completedTask = await client.pollTaskCompletionAsync(task.path);
    const { success, logs } = await client.getTaskLogsAsync(task.path);

    this._reportResult(args, completedTask.state, success, logs);
  };

  /**
   * --script-text mode: build and upload the place, then execute arbitrary
   * Luau code instead of the configured test script.
   */
  private _runWithScriptTextAsync = async (args: TestProjectArgs) => {
    const buildResult = await buildAndUploadAsync(args, 'test', 'test.rbxl');
    if (!buildResult) {
      OutputHelper.info(
        '[DRYRUN] Would build, upload, execute script, and report results'
      );
      return;
    }

    const { client, target, version, packagePath } = buildResult;

    const placeName = await buildPlaceNameAsync(packagePath);
    await tryRenamePlaceAsync(target.placeId, placeName);

    OutputHelper.info('Running script via Open Cloud...');

    const task = await client.createExecutionTaskAsync(
      target.universeId,
      target.placeId,
      version,
      args.scriptText!
    );

    const completedTask = await client.pollTaskCompletionAsync(task.path);
    const { success, logs } = await client.getTaskLogsAsync(task.path);

    this._reportResult(args, completedTask.state, success, logs);
  };

  private _reportResult(
    args: TestProjectArgs,
    taskState: string,
    success: boolean,
    logs: string
  ): void {
    const showLogs = args.logs || !success || taskState !== 'COMPLETE';

    if (logs && showLogs) {
      console.log(logs);
    } else if (showLogs) {
      OutputHelper.info('(no output from script)');
    }

    if (taskState === 'COMPLETE' && success) {
      OutputHelper.info('Tests passed!');
    } else if (taskState === 'COMPLETE' && !success) {
      OutputHelper.error(
        'Tests failed! See output above for more information.'
      );
      process.exit(1);
    } else {
      OutputHelper.error(`Task ended with state: ${taskState}`);
      process.exit(1);
    }
  }
}
