/**
 * `studio-bridge serve` -- start a dedicated bridge host process.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { serveHandlerAsync } from '../../commands/serve.js';

export interface ServeArgs extends StudioBridgeGlobalArgs {
  port?: number;
  json?: boolean;
  'log-level'?: string;
}

export class ServeCommand<T> implements CommandModule<T, ServeArgs> {
  public command = 'serve';
  public describe = 'Start a dedicated bridge host process';

  public builder = (args: Argv<T>) => {
    args.option('port', {
      type: 'number',
      default: 38741,
      describe: 'Port to listen on',
    });
    args.option('json', {
      type: 'boolean',
      default: false,
      describe: 'Output structured JSON lines',
    });
    args.option('log-level', {
      type: 'string',
      choices: ['silent', 'error', 'warn', 'info', 'debug'],
      default: 'info',
      describe: 'Log verbosity',
    });

    return args as Argv<ServeArgs>;
  };

  public handler = async (args: ServeArgs) => {
    try {
      await serveHandlerAsync({
        port: args.port,
        json: args.json,
        timeout: args.timeout,
      });
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };
}
