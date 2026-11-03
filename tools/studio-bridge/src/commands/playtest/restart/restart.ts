/**
 * `playtest restart` — stop the running playtest and start a new one in the
 * same mode, so it picks up code changed since it started. Starts one when
 * none is running.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type {
  BridgeConnection,
  BridgeSession,
  PlaytestMode,
} from '../../../bridge/index.js';
import {
  endPlaytestAsync,
  startPlaytestAsync,
  type StartedPlaytest,
} from '../playtest-sessions.js';
import { listPlaytestPlayersAsync } from '../player/playtest-players.js';
import {
  describePlaytest,
  formatPlaytestStartText,
  toPlaytestStartResult,
  type PlaytestStartResult,
} from '../start/start.js';

/** Studio refuses a new playtest until the old one has fully wound down. */
const START_ATTEMPTS = 5;
const START_RETRY_DELAY_MS = 1_000;

export interface PlaytestRestartOptions {
  /** Defaults to the running playtest's mode, or play when none is running. */
  mode?: PlaytestMode;
  /** Defaults to the running multiplayer test's player count. */
  players?: number;
  /** Picks the Studio: any of its sessions. */
  target?: string;
}

interface PlaytestRestartArgs {
  mode?: PlaytestMode;
  players?: number;
}

export async function playtestRestartHandlerAsync(
  connection: BridgeConnection,
  options: PlaytestRestartOptions = {}
): Promise<PlaytestStartResult> {
  const targetSession = options.target
    ? await connection.resolveSessionAsync(options.target)
    : undefined;
  const serverSession = findServerSession(
    connection,
    targetSession?.info.instanceId
  );

  if (!serverSession) {
    const editSession =
      targetSession?.context === 'edit'
        ? targetSession
        : await connection.resolveSessionAsync(
            undefined,
            'edit',
            targetSession?.info.instanceId
          );
    const playtest = await startWithRetryAsync(
      connection,
      editSession,
      options.mode ?? 'play',
      options.players
    );
    return toPlaytestStartResult(
      playtest,
      `No playtest was running; started one (${describePlaytest(playtest)})`
    );
  }

  const editSession = await connection.resolveSessionAsync(
    undefined,
    'edit',
    serverSession.info.instanceId
  );

  // Players added since the start count too, so read who is in the test now
  const livePlayers =
    options.players === undefined && options.mode === undefined
      ? await tryCountMultiplayerPlayersAsync(connection, serverSession)
      : undefined;
  const ended = await endPlaytestAsync(connection, serverSession);
  const mode = options.mode ?? ended.mode ?? 'play';
  const players =
    options.players ??
    (options.mode === undefined && ended.players !== undefined
      ? livePlayers || ended.players
      : undefined);
  const playtest = await startWithRetryAsync(
    connection,
    editSession,
    mode,
    players
  );
  return toPlaytestStartResult(
    playtest,
    `Playtest restarted (${describePlaytest(playtest)})`
  );
}

/** How many players the running test has, or undefined when it can't tell. */
async function tryCountMultiplayerPlayersAsync(
  connection: BridgeConnection,
  serverSession: BridgeSession
): Promise<number | undefined> {
  try {
    return (await listPlaytestPlayersAsync(connection, serverSession)).length;
  } catch {
    return undefined;
  }
}

/** The running playtest's server session, within `instanceId` when given. */
function findServerSession(
  connection: BridgeConnection,
  instanceId: string | undefined
): BridgeSession | undefined {
  const servers = connection
    .listSessions()
    .filter(
      (info) =>
        info.context === 'server' &&
        (instanceId === undefined || info.instanceId === instanceId)
    );

  if (servers.length > 1) {
    const list = servers
      .map((info) => `  - ${info.sessionId}: ${info.placeName}`)
      .join('\n');
    throw new Error(
      `Multiple playtests are running. Use --target <id> to pick one.\n${list}`
    );
  }

  return servers.length === 1
    ? connection.getSession(servers[0].sessionId)
    : undefined;
}

async function startWithRetryAsync(
  connection: BridgeConnection,
  editSession: BridgeSession,
  mode: PlaytestMode,
  players: number | undefined
): Promise<StartedPlaytest> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await startPlaytestAsync(connection, editSession, mode, players);
    } catch (err) {
      const stillWindingDown =
        err instanceof Error && err.message.includes('still in progress');
      if (!stillWindingDown || attempt >= START_ATTEMPTS) {
        throw err;
      }
      await new Promise((resolve) => setTimeout(resolve, START_RETRY_DELAY_MS));
    }
  }
}

export const playtestRestartCommand = defineCommand<
  PlaytestRestartArgs,
  PlaytestStartResult
>({
  group: 'playtest',
  name: 'restart',
  description:
    'Stop the running playtest and start a new one in the same mode, to pick up code changes',
  category: 'execution',
  safety: 'mutate',
  scope: 'connection',
  args: {
    mode: arg.option({
      description:
        "Start in this mode instead of the running playtest's (play or run)",
      choices: ['play', 'run'],
    }),
    players: arg.option({
      description:
        "Start a multiplayer test with this many players instead of the running playtest's",
      type: 'number',
    }),
  },
  cli: {
    format: formatPlaytestStartText,
  },
  handler: async (connection, args, targeting) =>
    playtestRestartHandlerAsync(connection, {
      mode: args.mode,
      players: args.players,
      target: targeting.target,
    }),
});
