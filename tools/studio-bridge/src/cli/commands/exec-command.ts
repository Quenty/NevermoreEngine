/**
 * `studio-bridge exec <code>` — execute inline Luau code in Roblox Studio.
 *
 * Supports two execution paths:
 * - Persistent session: when --session/--instance/--context is specified,
 *   connects via BridgeConnection and uses the exec handler.
 * - Legacy: launches a one-shot StudioBridgeServer via executeScriptAsync.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { execHandlerAsync } from '../../commands/exec.js';
import { formatAsJson, resolveMode } from '../format-output.js';
import {
  executeScriptAsync,
  resolvePlacePathAsync,
} from '../script-executor.js';
import { addSessionOptions, withSessionAsync } from '../with-connection.js';
import type { SessionCommandOptions } from '../with-connection.js';

export interface ExecArgs extends StudioBridgeGlobalArgs, SessionCommandOptions {
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
    addSessionOptions(args);

    return args as Argv<ExecArgs>;
  };

  public handler = async (args: ExecArgs) => {
    // Use persistent session path when session selection is specified
    if (args.session || args.instance || args.context) {
      return this._handleViaSessionAsync(args);
    }

    // Legacy path: one-shot execution via StudioBridgeServer
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

  private _handleViaSessionAsync = async (args: ExecArgs) => {
    await withSessionAsync(args, async (session) => {
      const result = await execHandlerAsync(session, {
        scriptContent: args.code,
        timeout: args.timeout,
      });

      const mode = resolveMode({ json: args.json });
      if (mode === 'json') {
        console.log(
          formatAsJson({
            success: result.success,
            output: result.output,
            error: result.error,
          })
        );
      } else {
        for (const line of result.output) {
          console.log(line);
        }
        OutputHelper.info(result.summary);
      }

      if (!result.success) {
        process.exit(1);
      }
    });
  };
}
