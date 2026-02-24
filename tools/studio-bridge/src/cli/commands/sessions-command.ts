/**
 * `studio-bridge sessions` — list active studio-bridge sessions.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { listSessionsHandlerAsync } from '../../commands/sessions.js';
import { formatAsJson, formatAsTable, resolveMode } from '../format-output.js';
import type { TableColumn } from '../format-output.js';
import type { SessionInfo } from '../../bridge/index.js';
import { withConnectionAsync } from '../with-connection.js';

export interface SessionsArgs extends StudioBridgeGlobalArgs {
  json?: boolean;
}

export class SessionsCommand<T> implements CommandModule<T, SessionsArgs> {
  public command = 'sessions';
  public describe = 'List active studio-bridge sessions';

  public builder = (args: Argv<T>) => {
    args.option('json', {
      type: 'boolean',
      default: false,
      describe: 'Output as JSON',
    });

    return args as Argv<SessionsArgs>;
  };

  public handler = async (args: SessionsArgs) => {
    await withConnectionAsync(args, { waitForSessions: true }, async (connection) => {
      const result = await listSessionsHandlerAsync(connection);

      const mode = resolveMode({ json: args.json });
      if (mode === 'json') {
        console.log(formatAsJson(result.sessions));
      } else {
        if (result.sessions.length === 0) {
          OutputHelper.warn(result.summary);
        } else {
          const columns: TableColumn<SessionInfo>[] = [
            { header: 'Session ID', value: (s) => s.sessionId },
            { header: 'Place', value: (s) => s.placeName },
            { header: 'Context', value: (s) => s.context },
            { header: 'State', value: (s) => s.state },
            { header: 'Origin', value: (s) => s.origin },
          ];

          console.log(formatAsTable(result.sessions, columns));
          OutputHelper.info(result.summary);
        }
      }
    });
  };
}
