/**
 * Starting, finding, and ending StudioTestService playtests.
 *
 * A playtest opens fresh server (and, in play mode, client) DataModels, and
 * each connects to the bridge as its own session. Those sessions can't be
 * matched to the Studio that started them by instance id, since unpublished
 * places give every DataModel its own. Instead, `startPlaytestAsync` passes a
 * playtest id as the StudioTestService test args, and each session registers
 * with it.
 *
 * The playtest's server session is the plugin when Studio loads user plugins
 * into playtests. Otherwise the edit plugin plants a copy of itself into the
 * playtest as an ordinary Script (see plugin/playtest-bridge.ts). That one can
 * only run code compiled when the playtest started: the actions, and the
 * scripts `startPlaytestAsync` is given.
 */

import { randomUUID } from 'crypto';
import type {
  BridgeConnection,
  BridgeSession,
  EndPlaytestResult,
  PlaytestEndResult,
  PlaytestMode,
  SessionContext,
} from '../../bridge/index.js';
import {
  ContextNotFoundError,
  SessionDisconnectedError,
} from '../../bridge/index.js';
import { withoutEndPunctuation } from '../../messages/describe-error.js';
import { ensureCurrentPluginAsync } from '../../cli/plugin-freshness.js';
import { buildPlaytestBridgeAsync } from '../../plugin/playtest-bridge.js';
import { tryReadLoadUserPluginsOnPlaytestAsync } from '../../process/studio-settings.js';
import {
  invalidInput,
  StudioBridgeError,
} from '../../messages/studio-bridge-error.js';

/** How long a started playtest may run before its pending start request is dropped. */
const PLAYTEST_MAX_DURATION_MS = 24 * 60 * 60 * 1000;

const SESSION_WAIT_TIMEOUT_MS = 30_000;
/** Each player of a multiplayer test boots its own Studio process. */
const MULTIPLAYER_SESSION_WAIT_TIMEOUT_MS = 90_000;
const SESSION_CLOSE_TIMEOUT_MS = 10_000;

export interface StartPlaytestOptions {
  /**
   * Code the caller will run in the playtest's server session. A server
   * session planted without plugin permissions can only run code compiled
   * when the playtest starts.
   */
  scripts?: string[];
  /** Wait for the server session only, so play mode needs no client plugin. */
  serverOnly?: boolean;
}

export interface StartedPlaytest {
  playtestId: string;
  mode: PlaytestMode;
  /** Set for a multiplayer test. */
  players?: number;
  /** The playtest's sessions: always `server`, plus `client` in play mode. */
  sessions: Partial<Record<SessionContext, BridgeSession>>;
  /** Every client session, one per player. */
  clients: BridgeSession[];
  /** Settles when the playtest ends. Never rejects. */
  ended: Promise<PlaytestEndResult>;
}

/** The sessions a playtest opens, by mode. Run mode has no player, so no client. */
export function getPlaytestContexts(mode: PlaytestMode): SessionContext[] {
  return mode === 'play' ? ['server', 'client'] : ['server'];
}

/**
 * Start a playtest from `editSession` and resolve once every session it opens
 * has connected. With `players`, it is a multiplayer test with a client per
 * player. Rejects if Studio refuses to start it, e.g. because a playtest is
 * already running.
 */
export async function startPlaytestAsync(
  connection: BridgeConnection,
  editSession: BridgeSession,
  mode: PlaytestMode,
  players?: number,
  options: StartPlaytestOptions = {}
): Promise<StartedPlaytest> {
  if (editSession.context !== 'edit') {
    throw new StudioBridgeError({
      code: 'PLAYTEST_NEEDS_EDIT',
      message: `Playtests start from Edit, but this targets the ${editSession.context} session.`,
      fix: 'Target Edit with --context edit.',
    });
  }
  const pluginsOnPlaytest = await tryReadPlaytestPluginsAsync(connection);
  if (players !== undefined) {
    assertValidMultiplayer(mode, players);
  }
  editSession = await ensureCurrentPluginAsync(connection, editSession);

  // A server plugin, when Studio does load one, stands down for a planted bridge
  const bridge =
    pluginsOnPlaytest === true
      ? undefined
      : await buildPlaytestBridgeAsync(options.scripts, {
          withClient:
            pluginsOnPlaytest === false &&
            mode === 'play' &&
            !options.serverOnly,
        });

  const playtestId = randomUUID();
  const ended = editSession
    .runPlaytestAsync(
      mode,
      playtestId,
      connection.port,
      PLAYTEST_MAX_DURATION_MS,
      players,
      bridge
    )
    .catch(
      (err): PlaytestEndResult => ({
        playtestId,
        success: false,
        error: err instanceof Error ? err.message : String(err),
      })
    );

  const clientCount = options.serverOnly
    ? 0
    : players ?? (mode === 'play' ? 1 : 0);
  const waitTimeoutMs =
    players !== undefined
      ? MULTIPLAYER_SESSION_WAIT_TIMEOUT_MS
      : SESSION_WAIT_TIMEOUT_MS;
  const abort = new AbortController();
  let outcome;
  try {
    outcome = await Promise.race([
      waitForPlaytestSessionsAsync(
        connection,
        playtestId,
        clientCount,
        waitTimeoutMs,
        abort.signal
      ).then((sessions) => ({ sessions })),
      ended.then((result) => ({ result })),
    ]);
  } finally {
    abort.abort();
  }

  if ('result' in outcome) {
    throw outcome.result.success
      ? new StudioBridgeError({
          code: 'PLAYTEST_ENDED',
          message: 'The playtest ended before it connected to studio-bridge.',
          fix: 'Check nothing stops it in Studio, then run the command again.',
        })
      : new StudioBridgeError({
          code: 'PLAYTEST_REFUSED',
          message: `Studio didn't start the playtest: ${withoutEndPunctuation(
            outcome.result.error ?? 'no reason given'
          )}.`,
          fix: "If a playtest is already running, stop it with 'studio-bridge playtest stop'.",
        });
  }

  const { server, clients } = outcome.sessions;
  const missing = [
    ...(server ? [] : ['server']),
    ...(clients.length < clientCount
      ? [`${clientCount - clients.length} client`]
      : []),
  ];
  if (server && missing.length === 0) {
    return {
      playtestId,
      mode,
      players,
      sessions: { server, client: clients[0] },
      clients,
      ended,
    };
  }

  const waited = `its ${missing.join(' and ')} session${
    missing.length > 1 || clientCount - clients.length > 1 ? 's' : ''
  } did not connect within ${waitTimeoutMs / 1000}s`;

  // Without its server session the playtest can't be ended from here
  if (!server?.isConnected) {
    throw new StudioBridgeError({
      code: 'PLAYTEST_NOT_CONNECTED',
      message: `The playtest started, but ${waited}.`,
      fix: 'Stop it in Studio, then run the command again.',
    });
  }

  await endPlaytestAsync(connection, server);
  throw new StudioBridgeError({
    code: 'PLAYTEST_NOT_CONNECTED',
    message: `The playtest started, but ${waited}, so it was stopped.`,
    fix: "Check Studio's Output for errors, then run the command again.",
  });
}

function assertValidMultiplayer(mode: PlaytestMode, players: number): void {
  if (!Number.isInteger(players) || players < 1) {
    throw invalidInput(
      `--players ${players} is out of range.`,
      'Give a whole number of at least 1.'
    );
  }
  if (mode !== 'play') {
    throw invalidInput(
      `A multiplayer test can't run in ${mode} mode.`,
      'Use --mode play with --players.'
    );
  }
}

/**
 * Resolve the server session of a running playtest. `target` names it or
 * any session of its Studio; otherwise there must be exactly one connected.
 */
export async function resolvePlaytestServerSessionAsync(
  connection: BridgeConnection,
  target?: string
): Promise<BridgeSession> {
  if (target) {
    try {
      return await connection.resolveSessionAsync(target, 'server');
    } catch (err) {
      throw await explainMissingPlaytestContextAsync(connection, err);
    }
  }

  const servers = connection
    .listSessions()
    .filter((info) => info.context === 'server');
  if (servers.length === 0) {
    throw await explainNoPlaytestAsync(connection);
  }
  if (servers.length > 1) {
    const list = servers
      .map((info) => `  - ${info.sessionId}: ${info.placeName}`)
      .join('\n');
    throw new StudioBridgeError({
      code: 'SESSION_NOT_FOUND',
      message: 'Several playtests are running, so this needs a --target.',
      fix: `Pick one with --target <id>:\n${list}`,
    });
  }

  const session = connection.getSession(servers[0].sessionId);
  if (!session) {
    throw new SessionDisconnectedError(servers[0].sessionId);
  }
  return session;
}

/**
 * Explains a missing `server` or `client` session: no playtest is running, a
 * run-mode playtest has no client, or the playtest's sessions can't connect.
 * Other errors pass through unchanged.
 */
export async function explainMissingPlaytestContextAsync(
  connection: BridgeConnection,
  err: unknown
): Promise<unknown> {
  if (
    !(err instanceof ContextNotFoundError) ||
    (err.context !== 'server' && err.context !== 'client')
  ) {
    return err;
  }

  const placeName = connection
    .listSessions()
    .find((info) => info.instanceId === err.instanceId)?.placeName;
  const studio = placeName ? `'${placeName}'` : `instance '${err.instanceId}'`;

  if (err.context === 'client' && err.availableContexts.includes('server')) {
    return new StudioBridgeError({
      code: 'CONTEXT_NOT_FOUND',
      message: `The playtest of ${studio} runs in Run mode, which has no client.`,
      fix: "Run 'studio-bridge playtest restart --mode play'.",
    });
  }
  return explainNoPlaytestAsync(connection, studio, err.context);
}

/**
 * Whether this machine's Studio has "Load user plugins on playtest" on. A
 * remote Studio's settings aren't on this machine, so they are unknown.
 */
async function tryReadPlaytestPluginsAsync(
  connection: BridgeConnection
): Promise<boolean | undefined> {
  return connection.isRemote
    ? undefined
    : await tryReadLoadUserPluginsOnPlaytestAsync();
}

async function explainNoPlaytestAsync(
  connection: BridgeConnection,
  studio?: string,
  context?: SessionContext
): Promise<StudioBridgeError> {
  const of = studio ? ` of ${studio}` : '';
  if (
    context === 'client' &&
    (await tryReadPlaytestPluginsAsync(connection)) === false
  ) {
    return new StudioBridgeError({
      code: 'NO_PLAYTEST',
      message: `No playtest client${of} is connected, since Studio's "Load user plugins on playtest" setting is off.`,
      fix: "Turn the setting on, or start the playtest with 'studio-bridge playtest start', which runs only code compiled when it starts.",
    });
  }
  const missing = context ? `, so there is no ${context} session` : '';
  return new StudioBridgeError({
    code: 'NO_PLAYTEST',
    message: `No playtest${of} is running${missing}.`,
    fix: "Start one with 'studio-bridge playtest start'.",
  });
}

/**
 * End the playtest `serverSession` belongs to, resolving once the session has
 * closed with what the playtest reported about itself.
 */
export async function endPlaytestAsync(
  connection: BridgeConnection,
  serverSession: BridgeSession
): Promise<EndPlaytestResult> {
  const ended = await serverSession.endPlaytestAsync();
  await waitForSessionCloseAsync(connection, serverSession.info.sessionId);
  return ended;
}

interface PlaytestSessions {
  server?: BridgeSession;
  clients: BridgeSession[];
}

async function waitForPlaytestSessionsAsync(
  connection: BridgeConnection,
  playtestId: string,
  clientCount: number,
  timeoutMs: number,
  signal: AbortSignal
): Promise<PlaytestSessions> {
  return new Promise((resolve) => {
    const found: PlaytestSessions = { clients: [] };

    const cleanup = () => {
      clearTimeout(timer);
      connection.off('session-connected', onSession);
      signal.removeEventListener('abort', cleanup);
    };

    const onSession = (session: BridgeSession) => {
      if (session.info.playtestId !== playtestId) {
        return;
      }

      if (session.context === 'server') {
        found.server = session;
      } else if (
        session.context === 'client' &&
        !found.clients.some((c) => c.info.sessionId === session.info.sessionId)
      ) {
        found.clients.push(session);
      }
      if (found.server && found.clients.length >= clientCount) {
        cleanup();
        resolve(found);
      }
    };

    // Resolves with whichever sessions connected; the caller reports the rest
    const timer = setTimeout(() => {
      cleanup();
      resolve(found);
    }, timeoutMs);

    signal.addEventListener('abort', cleanup);
    connection.on('session-connected', onSession);

    for (const info of connection.listSessions()) {
      const session = connection.getSession(info.sessionId);
      if (session) onSession(session);
    }
  });
}

async function waitForSessionCloseAsync(
  connection: BridgeConnection,
  sessionId: string
): Promise<void> {
  return new Promise((resolve, reject) => {
    if (!connection.getSession(sessionId)) {
      resolve();
      return;
    }

    const onDisconnected = (disconnectedId: string) => {
      if (disconnectedId !== sessionId) return;
      clearTimeout(timer);
      connection.off('session-disconnected', onDisconnected);
      resolve();
    };

    const timer = setTimeout(() => {
      connection.off('session-disconnected', onDisconnected);
      reject(
        new StudioBridgeError({
          code: 'PLAYTEST_STILL_RUNNING',
          message: `Asked the playtest to stop, but it was still running after ${
            SESSION_CLOSE_TIMEOUT_MS / 1000
          }s.`,
          fix: 'Stop it in Studio.',
        })
      );
    }, SESSION_CLOSE_TIMEOUT_MS);

    connection.on('session-disconnected', onDisconnected);
  });
}
