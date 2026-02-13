import { Argv, CommandModule } from 'yargs';
import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import { buildAndUploadAsync } from '../utils/build-and-upload.js';
import {
  createExecutionTaskAsync,
  pollTaskCompletionAsync,
  getTaskLogsAsync,
} from '../utils/open-cloud-client.js';

export interface TestProjectArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  logs?: boolean;
  universeId?: number;
  placeId?: number;
  script?: string;
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
      describe: 'Override universe ID from deploy.json',
      type: 'number',
    });
    args.option('place-id', {
      describe: 'Override place ID from deploy.json',
      type: 'number',
    });
    args.option('script', {
      describe: 'Override script path from deploy.json',
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
    const result = await buildAndUploadAsync(args, 'test', 'test.rbxl');
    if (!result) {
      OutputHelper.info(
        '[DRYRUN] Would build, upload, execute script, and report results'
      );
      return;
    }

    const { apiKey, target, version, packagePath } = result;

    let scriptContent: string;
    if (args.scriptText) {
      scriptContent = args.scriptText;
    } else if (target.script) {
      scriptContent = await _readScriptAsync(packagePath, target.script);
    } else {
      throw new Error(
        'No script to run. Provide --script-text, --script, or add a "script" field to your deploy.json test target.'
      );
    }

    OutputHelper.info('Running script via Open Cloud...');

    const task = await createExecutionTaskAsync(
      apiKey,
      target.universeId,
      target.placeId,
      version,
      scriptContent
    );

    const completedTask = await pollTaskCompletionAsync(
      apiKey,
      task.path
    );

    const { success, logs } = await getTaskLogsAsync(apiKey, task.path);

    const showLogs = args.logs || !success || completedTask.state !== 'COMPLETE';

    if (logs && showLogs) {
      console.log(logs);
    } else if (showLogs) {
      OutputHelper.info('(no output from script)');
    }

    if (completedTask.state === 'COMPLETE' && success) {
      OutputHelper.info('Tests passed!');
    } else if (completedTask.state === 'COMPLETE' && !success) {
      OutputHelper.error(
        'Tests failed! See output above for more information.'
      );
      process.exit(1);
    } else {
      OutputHelper.error(`Task ended with state: ${completedTask.state}`);
      process.exit(1);
    }
  };
}

async function _readScriptAsync(
  packagePath: string,
  scriptPath: string
): Promise<string> {
  const fullPath = path.resolve(packagePath, scriptPath);
  try {
    return await fs.readFile(fullPath, 'utf-8');
  } catch {
    throw new Error(`Test script not found: ${fullPath}`);
  }
}
