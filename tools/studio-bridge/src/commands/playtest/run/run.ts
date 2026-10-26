/**
 * `playtest run` — start a playtest, execute Luau inside it, then stop it.
 *
 * The code runs in the playtest's server by default, or its client with
 * `--context client`. Its output and return values come back the same way as
 * `console exec`.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { resolveScriptContentAsync } from '../../../cli/resolve-script-content.js';
import { execHandlerAsync, formatExecText } from '../../console/exec/exec.js';
import type {
  BridgeConnection,
  BridgeSession,
  PlaytestMode,
  SessionContext,
} from '../../../bridge/index.js';
import type { SerializedReturnValue } from '../../../server/web-socket-protocol.js';
import {
  endPlaytestAsync,
  getPlaytestContexts,
  startPlaytestAsync,
} from '../playtest-sessions.js';

export interface PlaytestRunOptions {
  scriptContent: string;
  mode: PlaytestMode;
  /** Which playtest DataModel runs the code. */
  context: SessionContext;
  /** Picks the edit session to start the playtest from. */
  target?: string;
  timeout?: number;
}

export interface PlaytestRunResult {
  success: boolean;
  playtestId: string;
  output: string[];
  error?: string;
  returnValues?: SerializedReturnValue[];
  /** Set when the script ran but the playtest could not be stopped. */
  stopError?: string;
  summary: string;
}

interface PlaytestRunArgs {
  code?: string;
  file?: string;
  mode?: PlaytestMode;
  timeout?: number;
}

export async function playtestRunHandlerAsync(
  connection: BridgeConnection,
  options: PlaytestRunOptions
): Promise<PlaytestRunResult> {
  if (!getPlaytestContexts(options.mode).includes(options.context)) {
    throw new Error(
      `A ${options.mode} mode playtest has no ${options.context} session to run code in`
    );
  }

  const editSession = await connection.resolveSessionAsync(
    options.target,
    'edit'
  );
  const playtest = await startPlaytestAsync(
    connection,
    editSession,
    options.mode
  );

  let result: PlaytestRunResult;
  try {
    const session = playtest.sessions[options.context];
    if (!session) {
      throw new Error(`Playtest has no ${options.context} session`);
    }

    result = {
      ...(await execHandlerAsync(session, {
        scriptContent: options.scriptContent,
        timeout: options.timeout,
      })),
      playtestId: playtest.playtestId,
    };
  } catch (err) {
    await tryEndPlaytestAsync(connection, playtest.sessions.server);
    throw err;
  }

  // A playtest left running keeps the script's result worth reporting
  const stopError = await tryEndPlaytestAsync(
    connection,
    playtest.sessions.server
  );
  return stopError ? { ...result, stopError } : result;
}

/** Ends the playtest, returning why it could not instead of throwing. */
async function tryEndPlaytestAsync(
  connection: BridgeConnection,
  serverSession: BridgeSession | undefined
): Promise<string | undefined> {
  // The script may have ended the playtest itself
  if (!serverSession?.isConnected) {
    return undefined;
  }

  try {
    await endPlaytestAsync(connection, serverSession);
    return undefined;
  } catch (err) {
    return err instanceof Error ? err.message : String(err);
  }
}

export const playtestRunCommand = defineCommand<
  PlaytestRunArgs,
  PlaytestRunResult
>({
  group: 'playtest',
  name: 'run',
  description:
    'Start a playtest, execute Luau in it, then stop it (--context picks server or client)',
  category: 'execution',
  safety: 'mutate',
  scope: 'connection',
  args: {
    code: arg.positional({
      description: 'Inline Luau code to execute',
      required: false,
    }),
    file: arg.option({
      description: 'Path to a Luau script file to execute',
      alias: 'f',
    }),
    mode: arg.option({
      description:
        'play runs a server and a client with a player, run runs only the server',
      choices: ['play', 'run'],
      default: 'play',
    }),
    timeout: arg.option({
      description: 'Execution timeout in milliseconds',
      type: 'number',
    }),
  },
  cli: {
    format: (result) =>
      result.stopError
        ? `${formatExecText(result)}\nPlaytest is still running: ${
            result.stopError
          }`
        : formatExecText(result),
  },
  handler: async (connection, args, targeting) => {
    const { scriptContent } = await resolveScriptContentAsync(args);

    return playtestRunHandlerAsync(connection, {
      scriptContent,
      mode: args.mode ?? 'play',
      context: targeting.context ?? 'server',
      target: targeting.target,
      timeout: args.timeout,
    });
  },
});
