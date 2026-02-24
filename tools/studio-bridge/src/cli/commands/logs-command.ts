/**
 * `studio-bridge logs` -- retrieve and stream output logs from Studio.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import type { LogEntry } from '../../bridge/index.js';
import type { OutputLevel } from '../../server/web-socket-protocol.js';
import { queryLogsHandlerAsync } from '../../commands/logs.js';
import { formatAsJson, formatAsTable, resolveMode } from '../format-output.js';
import type { TableColumn } from '../format-output.js';
import { addSessionOptions, withSessionAsync } from '../with-connection.js';
import type { SessionCommandOptions } from '../with-connection.js';

export interface LogsArgs extends StudioBridgeGlobalArgs, SessionCommandOptions {
  tail?: number;
  head?: number;
  follow?: boolean;
  level?: string;
  all?: boolean;
}

export class LogsCommand<T> implements CommandModule<T, LogsArgs> {
  public command = 'logs';
  public describe = 'Retrieve and stream output logs from Studio';

  public builder = (args: Argv<T>) => {
    addSessionOptions(args);
    args.option('tail', {
      type: 'number',
      default: 50,
      describe: 'Number of most recent log entries to retrieve',
    });
    args.option('head', {
      type: 'number',
      describe: 'Number of oldest log entries to retrieve',
    });
    args.option('follow', {
      alias: 'f',
      type: 'boolean',
      default: false,
      describe: 'Follow log output (stream new entries)',
    });
    args.option('level', {
      alias: 'l',
      type: 'string',
      describe: 'Filter by log level (comma-separated: Print,Warning,Error)',
    });
    args.option('all', {
      type: 'boolean',
      default: false,
      describe: 'Include internal messages',
    });

    return args as Argv<LogsArgs>;
  };

  public handler = async (args: LogsArgs) => {
    await withSessionAsync(args, async (session) => {
      // Determine direction and count from --head / --tail flags
      let direction: 'head' | 'tail' = 'tail';
      let count: number = args.tail ?? 50;
      if (args.head !== undefined) {
        direction = 'head';
        count = args.head;
      }

      // Parse --level into an array of OutputLevel strings
      let levels: OutputLevel[] | undefined;
      if (args.level) {
        levels = args.level.split(',').map((l) => l.trim()) as OutputLevel[];
      }

      const result = await queryLogsHandlerAsync(session, {
        count,
        direction,
        levels,
        includeInternal: args.all || undefined,
      });

      const mode = resolveMode({ json: args.json });
      if (mode === 'json') {
        console.log(formatAsJson(result));
      } else {
        if (result.entries.length === 0) {
          OutputHelper.warn('No log entries found.');
        } else {
          const columns: TableColumn<LogEntry>[] = [
            {
              header: 'Time',
              value: (e) => new Date(e.timestamp).toLocaleTimeString(),
            },
            { header: 'Level', value: (e) => e.level },
            { header: 'Message', value: (e) => e.body },
          ];

          console.log(formatAsTable(result.entries, columns));
        }
        OutputHelper.info(result.summary);
      }

      // --follow: subscribe to live log push events
      if (args.follow) {
        OutputHelper.warn('Follow mode (--follow) is not yet supported.');
      }
    });
  };
}
