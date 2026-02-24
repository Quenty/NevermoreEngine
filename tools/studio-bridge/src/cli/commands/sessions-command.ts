/**
 * `studio-bridge sessions` — list active studio-bridge sessions.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { BridgeConnection } from '../../bridge/index.js';
import { listSessionsHandlerAsync } from '../../commands/sessions.js';
import { formatAsJson, formatAsTable, resolveMode } from '../format-output.js';
import type { TableColumn } from '../format-output.js';
import type { SessionInfo } from '../../bridge/index.js';

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
    let connection: BridgeConnection | undefined;
    try {
      connection = await BridgeConnection.connectAsync({ timeoutMs: args.timeout });

      // If we became the host, no server was running before we connected.
      // Wait briefly for a session so the plugin has a chance to discover us.
      if (connection.role === 'host') {
        try {
          await connection.waitForSession(5_000);
        } catch {
          // No session appeared — that's fine, report empty below.
        }
      }

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
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    } finally {
      if (connection) {
        await connection.disconnectAsync();
      }
    }
  };
}
