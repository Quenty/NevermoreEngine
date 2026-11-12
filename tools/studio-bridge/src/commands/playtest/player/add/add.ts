/**
 * `playtest player add` — add players to the running multiplayer test.
 */

import { formatCount } from '@quenty/cli-output-helpers/reporting';
import { defineCommand } from '../../../framework/define-command.js';
import { arg } from '../../../framework/arg-builder.js';
import type { BridgeConnection } from '../../../../bridge/index.js';
import { resolvePlaytestServerSessionAsync } from '../../playtest-sessions.js';
import {
  addPlaytestPlayersAsync,
  formatPlayersTable,
  type PlaytestPlayer,
} from '../playtest-players.js';
import { invalidInput } from '../../../../messages/studio-bridge-error.js';

export interface PlaytestPlayerAddResult {
  players: PlaytestPlayer[];
  summary: string;
}

interface PlaytestPlayerAddArgs {
  count?: number;
}

export async function playtestPlayerAddHandlerAsync(
  connection: BridgeConnection,
  count: number,
  target?: string
): Promise<PlaytestPlayerAddResult> {
  if (!Number.isInteger(count) || count < 1) {
    throw invalidInput(
      `Can't add ${count} players.`,
      'Give a whole number of at least 1.'
    );
  }

  const serverSession = await resolvePlaytestServerSessionAsync(
    connection,
    target
  );
  const players = await addPlaytestPlayersAsync(
    connection,
    serverSession,
    count
  );

  return {
    players,
    summary:
      players.length < count
        ? `Added ${players.length} of ${formatCount(
            count,
            'player',
            'players'
          )}; the rest did not join in time`
        : `Added ${formatCount(players.length, 'player', 'players')}`,
  };
}

export function formatPlayerAddText(result: PlaytestPlayerAddResult): string {
  return formatPlayersTable(result.players);
}

export const playtestPlayerAddCommand = defineCommand<
  PlaytestPlayerAddArgs,
  PlaytestPlayerAddResult
>({
  group: 'playtest player',
  name: 'add',
  description:
    'Add players to the running multiplayer test (playtest start --players)',
  category: 'execution',
  safety: 'mutate',
  scope: 'connection',
  args: {
    count: arg.positional({
      description: 'How many players to add',
      type: 'number',
      required: false,
    }),
  },
  cli: {
    body: formatPlayerAddText,
  },
  handler: async (connection, args, targeting) =>
    playtestPlayerAddHandlerAsync(
      connection,
      args.count ?? 1,
      targeting.target
    ),
});
