/**
 * `playtest stop` — end a running playtest from its server session.
 */

import { defineCommand } from '../../framework/define-command.js';
import type { BridgeConnection } from '../../../bridge/index.js';
import {
  endPlaytestAsync,
  resolvePlaytestServerSessionAsync,
} from '../playtest-sessions.js';

export interface PlaytestStopOptions {
  target?: string;
}

export interface PlaytestStopResult {
  /** Absent when the playtest was not started by studio-bridge. */
  playtestId?: string;
  summary: string;
}

export async function playtestStopHandlerAsync(
  connection: BridgeConnection,
  options: PlaytestStopOptions = {}
): Promise<PlaytestStopResult> {
  const serverSession = await resolvePlaytestServerSessionAsync(
    connection,
    options.target
  );
  const { playtestId } = await endPlaytestAsync(connection, serverSession);

  return {
    playtestId,
    summary: 'Playtest stopped',
  };
}

export const playtestStopCommand = defineCommand<
  Record<string, never>,
  PlaytestStopResult
>({
  group: 'playtest',
  name: 'stop',
  description: 'Stop the running playtest (--target picks its server session)',
  category: 'execution',
  safety: 'mutate',
  scope: 'connection',
  args: {},
  handler: async (connection, _args, targeting) =>
    playtestStopHandlerAsync(connection, { target: targeting.target }),
});
