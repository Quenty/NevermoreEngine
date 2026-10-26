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
import { startPlaytestAsync } from '../playtest-sessions.js';

export interface PlaytestStartOptions {
  mode: PlaytestMode;
  target?: string;
}

export interface PlaytestStartResult {
  playtestId: string;
  mode: PlaytestMode;
  sessions: Array<{ sessionId: string; context: SessionContext }>;
  summary: string;
}

interface PlaytestStartArgs {
  mode?: PlaytestMode;
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
    options.mode
  );

  const sessions = Object.values(playtest.sessions).map((session) => ({
    sessionId: session.info.sessionId,
    context: session.context,
  }));

  return {
    playtestId: playtest.playtestId,
    mode: playtest.mode,
    sessions,
    summary: `Playtest started (${playtest.mode} mode)`,
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
  },
  cli: {
    format: formatPlaytestStartText,
  },
  handler: async (connection, args, targeting) =>
    playtestStartHandlerAsync(connection, {
      mode: args.mode ?? 'play',
      target: targeting.target,
    }),
});
