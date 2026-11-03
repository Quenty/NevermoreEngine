/**
 * `playtest player add` — add players to the running multiplayer test.
 */

import { defineCommand } from '../../../framework/define-command.js';
import { arg } from '../../../framework/arg-builder.js';
import type { BridgeConnection } from '../../../../bridge/index.js';
import { resolvePlaytestServerSessionAsync } from '../../playtest-sessions.js';
import {
  addPlaytestPlayersAsync,
  formatPlayersTable,
  type PlaytestPlayer,
} from '../playtest-players.js';

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
    throw new Error(`Player count must be a whole number of at least 1`);
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
        ? `Added ${players.length} of ${count} player(s); the rest did not join in time`
        : `Added ${players.length} player(s)`,
  };
}

export function formatPlayerAddText(result: PlaytestPlayerAddResult): string {
  return result.players.length === 0
    ? result.summary
    : `${result.summary}\n${formatPlayersTable(result.players)}`;
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
    format: formatPlayerAddText,
  },
  handler: async (connection, args, targeting) =>
    playtestPlayerAddHandlerAsync(
      connection,
      args.count ?? 1,
      targeting.target
    ),
});
