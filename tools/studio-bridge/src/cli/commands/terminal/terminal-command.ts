/**
 * `studio-bridge terminal` — interactive REPL mode for executing Luau
 * scripts repeatedly in a persistent Studio session.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../../args/global-args.js';
import { resolvePlacePathAsync } from '../../script-executor.js';

export interface TerminalArgs extends StudioBridgeGlobalArgs {
  script?: string;
  'script-text'?: string;
}

export class TerminalCommand<T> implements CommandModule<T, TerminalArgs> {
  public command = 'terminal';
  public describe =
    'Interactive terminal mode — keep Studio alive and execute scripts via REPL';

  public builder = (args: Argv<T>) => {
    args.option('script', {
      alias: 's',
      describe: 'Path to a Luau script to run on connect',
      type: 'string',
    });

    args.option('script-text', {
      alias: 't',
      describe: 'Inline Luau code to run on connect',
      type: 'string',
    });

    return args as Argv<TerminalArgs>;
  };

  public handler = async (args: TerminalArgs) => {
    try {
      const placePath = await resolvePlacePathAsync(args.place);

      const { runTerminalMode } = await import('./terminal-mode.js');
      await runTerminalMode({
        placePath,
        scriptPath: args.script,
        scriptText: args['script-text'],
        timeoutMs: args.timeout,
        verbose: args.verbose,
      });
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };
}
