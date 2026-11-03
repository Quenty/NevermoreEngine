/**
 * `playtest player list` — list the players in the running playtest.
 */

import { defineCommand } from '../../../framework/define-command.js';
import type { BridgeConnection } from '../../../../bridge/index.js';
import { resolvePlaytestServerSessionAsync } from '../../playtest-sessions.js';
import {
  formatPlayersTable,
  listPlaytestPlayersAsync,
  type PlaytestPlayer,
} from '../playtest-players.js';

export interface PlaytestPlayerListResult {
  players: PlaytestPlayer[];
  summary: string;
}

export async function playtestPlayerListHandlerAsync(
  connection: BridgeConnection,
  target?: string
): Promise<PlaytestPlayerListResult> {
  const serverSession = await resolvePlaytestServerSessionAsync(
    connection,
    target
  );
  const players = await listPlaytestPlayersAsync(connection, serverSession);

  return {
    players,
    summary: `${players.length} player(s) in the playtest`,
  };
}

export function formatPlayerListText(result: PlaytestPlayerListResult): string {
  return result.players.length === 0
    ? 'No players in the playtest'
    : formatPlayersTable(result.players);
}

export const playtestPlayerListCommand = defineCommand<
  Record<string, never>,
  PlaytestPlayerListResult
>({
  group: 'playtest player',
  name: 'list',
  description: 'List the players in the running playtest',
  category: 'execution',
  safety: 'read',
  scope: 'connection',
  args: {},
  cli: {
    format: formatPlayerListText,
  },
  handler: async (connection, _args, targeting) =>
    playtestPlayerListHandlerAsync(connection, targeting.target),
});
