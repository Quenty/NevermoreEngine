/**
 * `playtest run` — start a playtest, execute Luau inside it, then stop it.
 *
 * The code runs in the playtest's server by default, or its client with
 * `--context client`. Its output and return values come back the same way as
 * `console exec`.
 *
 * Both run through the playtest's sessions. The server session works even
 * when Studio does not load user plugins into playtests, since the edit
 * session then plants it, with this code compiled ahead of time (see
 * playtest-sessions.ts). The client session needs that Studio setting on.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { resolveScriptContentAsync } from '../../../cli/resolve-script-content.js';
import {
  execHandlerAsync,
  formatExecText,
  INPUT_ARG_DESCRIPTION,
  readInputFilesAsync,
} from '../../console/exec/exec.js';
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
import {
  invalidInput,
  StudioBridgeError,
} from '../../../messages/studio-bridge-error.js';

export interface PlaytestRunOptions {
  scriptContent: string;
  mode: PlaytestMode;
  /** Which playtest DataModel runs the code. */
  context: SessionContext;
  /** Picks the edit session to start the playtest from. */
  target?: string;
  timeout?: number;
  /** Passed to the script as `...`. */
  args?: string[];
  /** Passed to the script as buffers in `...`, before `args`. */
  inputs?: Buffer[];
}

const PLAYER_JOIN_TIMEOUT_MS = 30_000;

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
  scriptTimeout?: number;
  scriptArgs?: string[];
  input?: string[];
}

export async function playtestRunHandlerAsync(
  connection: BridgeConnection,
  options: PlaytestRunOptions
): Promise<PlaytestRunResult> {
  if (!getPlaytestContexts(options.mode).includes(options.context)) {
    throw invalidInput(
      `A ${options.mode}-mode playtest has no ${options.context} to run code in.`,
      'Use --mode play to run code in the client.'
    );
  }

  const editSession = await connection.resolveSessionAsync(
    options.target,
    'edit'
  );

  const playtest = await startPlaytestAsync(
    connection,
    editSession,
    options.mode,
    undefined,
    {
      scripts: [options.scriptContent],
      serverOnly: options.context === 'server',
    }
  );

  let result: PlaytestRunResult;
  try {
    const session = playtest.sessions[options.context];
    if (!session) {
      throw new Error(`The playtest has no ${options.context} session`);
    }
    // In play mode the server's code expects the player, who joins a moment later
    if (options.mode === 'play' && options.context === 'server') {
      await waitForPlayerAsync(session);
    }

    result = {
      ...(await execHandlerAsync(session, {
        scriptContent: options.scriptContent,
        timeout: options.timeout,
        args: options.args,
        inputs: options.inputs,
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

async function waitForPlayerAsync(serverSession: BridgeSession): Promise<void> {
  const deadline = Date.now() + PLAYER_JOIN_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const { players } = await serverSession.playtestPlayersAsync(
      { op: 'list' },
      PLAYER_JOIN_TIMEOUT_MS
    );
    if (players.length > 0) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new StudioBridgeError({
    code: 'PLAYTEST_NO_PLAYER',
    message: `No player joined the playtest within ${
      PLAYER_JOIN_TIMEOUT_MS / 1000
    }s, so the server code didn't run.`,
    fix: 'Check the playtest in Studio, then run the command again.',
  });
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
    scriptTimeout: arg.option({
      description: 'Cancel the script after this many milliseconds',
      type: 'number',
    }),
    input: arg.option({
      description: INPUT_ARG_DESCRIPTION,
      array: true,
    }),
    scriptArgs: arg.passthrough({
      description:
        'Arguments after --, passed to the script as ... (all strings)',
    }),
  },
  cli: {
    output: 'data',
    body: (result) =>
      [
        formatExecText(result),
        result.stopError && `Playtest is still running: ${result.stopError}`,
      ]
        .filter(Boolean)
        .join('\n'),
  },
  handler: async (connection, args, targeting) => {
    const { scriptContent } = await resolveScriptContentAsync(args);
    const inputs = await readInputFilesAsync(args.input);

    return playtestRunHandlerAsync(connection, {
      scriptContent,
      mode: args.mode ?? 'play',
      context: targeting.context ?? 'server',
      target: targeting.target,
      timeout: args.scriptTimeout,
      args: args.scriptArgs,
      inputs,
    });
  },
});
