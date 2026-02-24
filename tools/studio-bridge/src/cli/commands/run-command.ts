/**
 * `studio-bridge run <file>` — execute a Luau script file in Roblox Studio.
 *
 * Supports two execution paths:
 * - Persistent session: when --session/--instance/--context is specified,
 *   connects via BridgeConnection and uses the run handler.
 * - Legacy: launches a one-shot StudioBridgeServer via executeScriptAsync.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { runHandlerAsync } from '../../commands/run.js';
import { formatAsJson, resolveMode } from '../format-output.js';
import {
  executeScriptAsync,
  resolvePlacePathAsync,
} from '../script-executor.js';
import { addSessionOptions, withSessionAsync } from '../with-connection.js';
import type { SessionCommandOptions } from '../with-connection.js';

export interface RunArgs extends StudioBridgeGlobalArgs, SessionCommandOptions {
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
    addSessionOptions(args);

    return args as Argv<RunArgs>;
  };

  public handler = async (args: RunArgs) => {
    // Use persistent session path when session selection is specified
    if (args.session || args.instance || args.context) {
      return this._handleViaSessionAsync(args);
    }

    // Legacy path: one-shot execution via StudioBridgeServer
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
      const packageName = path.basename(args.file, path.extname(args.file));

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

  private _handleViaSessionAsync = async (args: RunArgs) => {
    const scriptPath = path.resolve(args.file);

    await withSessionAsync(args, async (session) => {
      const result = await runHandlerAsync(session, {
        scriptPath,
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
