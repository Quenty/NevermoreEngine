/**
 * `playtest player remove` — remove players from the running playtest.
 */

import { defineCommand } from '../../../framework/define-command.js';
import { arg } from '../../../framework/arg-builder.js';
import type { BridgeConnection } from '../../../../bridge/index.js';
import { resolvePlaytestServerSessionAsync } from '../../playtest-sessions.js';
import {
  removePlaytestPlayersAsync,
  type RemovedPlayer,
} from '../playtest-players.js';

export interface PlaytestPlayerRemoveResult {
  players: RemovedPlayer[];
  summary: string;
}

interface PlaytestPlayerRemoveArgs {
  names: string[];
}

export async function playtestPlayerRemoveHandlerAsync(
  connection: BridgeConnection,
  names: string[],
  target?: string
): Promise<PlaytestPlayerRemoveResult> {
  const serverSession = await resolvePlaytestServerSessionAsync(
    connection,
    target
  );
  const players = await removePlaytestPlayersAsync(
    connection,
    serverSession,
    names
  );

  return {
    players,
    summary: `Removed ${players.map((p) => p.name).join(', ')}`,
  };
}

export function formatPlayerRemoveText(
  result: PlaytestPlayerRemoveResult
): string {
  const kicked = result.players.filter((p) => p.how === 'kicked');
  if (kicked.length === 0) return result.summary;

  return `${result.summary}\nKicked ${kicked
    .map((p) => p.name)
    .join(
      ', '
    )}, whose client session was not connected, so its window stays open`;
}

export const playtestPlayerRemoveCommand = defineCommand<
  PlaytestPlayerRemoveArgs,
  PlaytestPlayerRemoveResult
>({
  group: 'playtest player',
  name: 'remove',
  description: 'Remove players from the running playtest by name',
  category: 'execution',
  safety: 'mutate',
  scope: 'connection',
  args: {
    names: arg.positional({
      description: 'Player names (e.g. Player2)',
      array: true,
    }),
  },
  cli: {
    format: formatPlayerRemoveText,
  },
  handler: async (connection, args, targeting) =>
    playtestPlayerRemoveHandlerAsync(connection, args.names, targeting.target),
});
