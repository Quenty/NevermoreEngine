/**
 * `playtest start` — start a StudioTestService playtest and leave it running.
 *
 * Resolves once the playtest's sessions connect, so the next command can
 * target them with `--context server` or `--context client`.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type {
  BridgeConnection,
  PlaytestMode,
  SessionContext,
} from '../../../bridge/index.js';
import {
  startPlaytestAsync,
  type StartedPlaytest,
} from '../playtest-sessions.js';

export interface PlaytestStartOptions {
  mode: PlaytestMode;
  /** Starts a multiplayer test with this many players. */
  players?: number;
  target?: string;
}

export interface PlaytestStartResult {
  playtestId: string;
  mode: PlaytestMode;
  /** How many players a multiplayer test started with. */
  playerCount?: number;
  sessions: Array<{
    sessionId: string;
    context: SessionContext;
    playerName?: string;
  }>;
  summary: string;
}

interface PlaytestStartArgs {
  mode?: PlaytestMode;
  players?: number;
}

export async function playtestStartHandlerAsync(
  connection: BridgeConnection,
  options: PlaytestStartOptions
): Promise<PlaytestStartResult> {
  const editSession = await connection.resolveSessionAsync(
    options.target,
    'edit'
  );
  const playtest = await startPlaytestAsync(
    connection,
    editSession,
    options.mode,
    options.players
  );

  return toPlaytestStartResult(
    playtest,
    `Playtest started (${describePlaytest(playtest)})`
  );
}

/** `play mode`, `run mode`, or `3 players` for a multiplayer test. */
export function describePlaytest(playtest: {
  mode: PlaytestMode;
  players?: number;
}): string {
  return playtest.players !== undefined
    ? `${playtest.players} player${playtest.players === 1 ? '' : 's'}`
    : `${playtest.mode} mode`;
}

/** Report a started playtest and the sessions it opened. */
export function toPlaytestStartResult(
  playtest: StartedPlaytest,
  summary: string
): PlaytestStartResult {
  return {
    playtestId: playtest.playtestId,
    mode: playtest.mode,
    playerCount: playtest.players,
    sessions: [playtest.sessions.server, ...playtest.clients]
      .filter((session) => session !== undefined)
      .map((session) => ({
        sessionId: session.info.sessionId,
        context: session.context,
        playerName: session.info.playerName,
      })),
    summary,
  };
}

export function formatPlaytestStartText(result: PlaytestStartResult): string {
  return [
    result.summary,
    ...result.sessions.map(
      (session) => `  ${session.context.padEnd(7)}${session.sessionId}`
    ),
  ].join('\n');
}

export const playtestStartCommand = defineCommand<
  PlaytestStartArgs,
  PlaytestStartResult
>({
  group: 'playtest',
  name: 'start',
  description:
    'Start a playtest and leave it running (--target picks the edit session)',
  category: 'execution',
  safety: 'mutate',
  scope: 'connection',
  args: {
    mode: arg.option({
      description:
        'play runs a server and a client with a player, run runs only the server',
      choices: ['play', 'run'],
      default: 'play',
    }),
    players: arg.option({
      description:
        'Start a multiplayer test: a server and a client per player, each in its own Studio window',
      type: 'number',
    }),
  },
  cli: {
    format: formatPlaytestStartText,
  },
  handler: async (connection, args, targeting) =>
    playtestStartHandlerAsync(connection, {
      mode: args.mode ?? 'play',
      players: args.players,
      target: targeting.target,
    }),
});
