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
import {
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
  /** Picks the Studio: any of its sessions. */
  target?: string;
}

interface PlaytestRestartArgs {
  mode?: PlaytestMode;
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
    const mode = options.mode ?? 'play';
    const playtest = await startWithRetryAsync(connection, editSession, mode);
    return toPlaytestStartResult(
      playtest,
      `No playtest was running; started one (${mode} mode)`
    );
  }

  const editSession = await connection.resolveSessionAsync(
    undefined,
    'edit',
    serverSession.info.instanceId
  );

  const ended = await endPlaytestAsync(connection, serverSession);
  const mode = options.mode ?? ended.mode ?? 'play';
  const playtest = await startWithRetryAsync(connection, editSession, mode);
  return toPlaytestStartResult(playtest, `Playtest restarted (${mode} mode)`);
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
  mode: PlaytestMode
): Promise<StartedPlaytest> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await startPlaytestAsync(connection, editSession, mode);
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
  },
  cli: {
    format: formatPlaytestStartText,
  },
  handler: async (connection, args, targeting) =>
    playtestRestartHandlerAsync(connection, {
      mode: args.mode,
      target: targeting.target,
    }),
});
