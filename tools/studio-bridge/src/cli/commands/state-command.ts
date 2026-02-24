/**
 * `studio-bridge state` -- query the current Studio state.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { BridgeConnection } from '../../bridge/index.js';
import type { SessionContext } from '../../bridge/index.js';
import { queryStateHandlerAsync } from '../../commands/state.js';
import { formatAsJson, formatAsTable, resolveMode } from '../format-output.js';
import type { TableColumn } from '../format-output.js';

export interface StateArgs extends StudioBridgeGlobalArgs {
  session?: string;
  instance?: string;
  context?: string;
  json?: boolean;
}

export class StateCommand<T> implements CommandModule<T, StateArgs> {
  public command = 'state';
  public describe = 'Query the current Studio state';

  public builder = (args: Argv<T>) => {
    args.option('session', {
      alias: 's',
      type: 'string',
      describe: 'Target session ID',
    });
    args.option('instance', {
      type: 'string',
      describe: 'Target instance ID',
    });
    args.option('context', {
      type: 'string',
      describe: 'Target context (edit, client, server)',
    });
    args.option('json', {
      type: 'boolean',
      default: false,
      describe: 'Output as JSON',
    });

    return args as Argv<StateArgs>;
  };

  public handler = async (args: StateArgs) => {
    let connection: BridgeConnection | undefined;
    try {
      connection = await BridgeConnection.connectAsync({
        timeoutMs: args.timeout,
      });
      const session = await connection.resolveSessionAsync(
        args.session,
        args.context as SessionContext | undefined,
        args.instance
      );

      const result = await queryStateHandlerAsync(session);

      const mode = resolveMode({ json: args.json });
      if (mode === 'json') {
        console.log(
          formatAsJson({
            state: result.state,
            placeId: result.placeId,
            placeName: result.placeName,
            gameId: result.gameId,
          })
        );
      } else {
        const rows = [result];
        const columns: TableColumn<typeof result>[] = [
          { header: 'Mode', value: (r) => r.state },
          { header: 'Place', value: (r) => r.placeName },
          { header: 'PlaceId', value: (r) => String(r.placeId) },
          { header: 'GameId', value: (r) => String(r.gameId) },
        ];

        console.log(formatAsTable(rows, columns));
        OutputHelper.info(result.summary);
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
