/**
 * `studio-bridge exec <code>` — execute inline Luau code in Roblox Studio.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import {
  executeScriptAsync,
  resolvePlacePathAsync,
} from '../script-executor.js';

export interface ExecArgs extends StudioBridgeGlobalArgs {
  code: string;
}

export class ExecCommand<T> implements CommandModule<T, ExecArgs> {
  public command = 'exec <code>';
  public describe = 'Execute inline Luau code in Roblox Studio';

  public builder = (args: Argv<T>) => {
    args.positional('code', {
      describe: 'Luau code to execute',
      type: 'string',
      demandOption: true,
    });

    return args as Argv<ExecArgs>;
  };

  public handler = async (args: ExecArgs) => {
    try {
      const placePath = await resolvePlacePathAsync(args.place);

      await executeScriptAsync({
        scriptContent: args.code,
        packageName: 'script',
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
