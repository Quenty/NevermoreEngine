/**
 * `studio-bridge state` -- query the current Studio state.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { queryStateHandlerAsync } from '../../commands/state.js';
import { formatAsJson, formatAsTable, resolveMode } from '../format-output.js';
import type { TableColumn } from '../format-output.js';
import { addSessionOptions, withSessionAsync } from '../with-connection.js';
import type { SessionCommandOptions } from '../with-connection.js';

export interface StateArgs extends StudioBridgeGlobalArgs, SessionCommandOptions {}

export class StateCommand<T> implements CommandModule<T, StateArgs> {
  public command = 'state';
  public describe = 'Query the current Studio state';

  public builder = (args: Argv<T>) => {
    addSessionOptions(args);
    return args as Argv<StateArgs>;
  };

  public handler = async (args: StateArgs) => {
    await withSessionAsync(args, async (session) => {
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
    });
  };
}
