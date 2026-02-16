/**
 * `studio-bridge run <file>` — execute a Luau script file in Roblox Studio.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import {
  executeScriptAsync,
  resolvePlacePathAsync,
} from '../script-executor.js';

export interface RunArgs extends StudioBridgeGlobalArgs {
  file: string;
}

export class RunCommand<T> implements CommandModule<T, RunArgs> {
  public command = 'run <file>';
  public describe = 'Execute a Luau script file in Roblox Studio';

  public builder = (args: Argv<T>) => {
    args.positional('file', {
      describe: 'Path to a Luau script file',
      type: 'string',
      demandOption: true,
    });

    return args as Argv<RunArgs>;
  };

  public handler = async (args: RunArgs) => {
    try {
      const scriptPath = path.resolve(args.file);
      let scriptContent: string;
      try {
        scriptContent = await fs.readFile(scriptPath, 'utf-8');
      } catch {
        OutputHelper.error(`Could not read script file: ${scriptPath}`);
        process.exit(1);
      }

      const placePath = await resolvePlacePathAsync(args.place);
      const packageName = path.basename(
        args.file,
        path.extname(args.file)
      );

      await executeScriptAsync({
        scriptContent,
        packageName,
        placePath,
        timeoutMs: args.timeout,
        verbose: args.verbose,
        showLogs: args.logs,
      });
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };
}
