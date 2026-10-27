/**
 * Starting, finding, and ending StudioTestService playtests.
 *
 * A playtest opens fresh server (and, in play mode, client) DataModels, and
 * each connects to the bridge as its own session. Those sessions can't be
 * matched to the Studio that started them by instance id, since unpublished
 * places give every DataModel its own. Instead, `startPlaytestAsync` passes a
 * playtest id as the StudioTestService test args, and each new session is
 * asked for it back through `GetTestArgs`.
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
import { ContextNotFoundError } from '../../bridge/index.js';
import { getPluginBuildVersionAsync } from '../../plugin/plugin-build-version.js';

/** How long a started playtest may run before its pending start request is dropped. */
const PLAYTEST_MAX_DURATION_MS = 24 * 60 * 60 * 1000;

const SESSION_WAIT_TIMEOUT_MS = 30_000;
/** Each player of a multiplayer test boots its own Studio process. */
const MULTIPLAYER_SESSION_WAIT_TIMEOUT_MS = 90_000;
const SESSION_CLOSE_TIMEOUT_MS = 10_000;
const READ_RETRY_DELAY_MS = 1_000;

const READ_PLAYTEST_ID_SCRIPT = [
  'local ok, args = pcall(function()',
  '\treturn game:GetService("StudioTestService"):GetTestArgs()',
  'end)',
  'return if ok and type(args) == "table" then args.studioBridgePlaytestId else nil',
].join('\n');

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
  players?: number
): Promise<StartedPlaytest> {
  if (editSession.context !== 'edit') {
    throw new Error(
      `Playtests start from an edit session, but '${editSession.info.sessionId}' is a ${editSession.context} session`
    );
  }
  if (players !== undefined) {
    await assertCanStartMultiplayerAsync(editSession, mode, players);
  }

  const playtestId = randomUUID();
  const ended = editSession
    .runPlaytestAsync(
      mode,
      playtestId,
      connection.port,
      PLAYTEST_MAX_DURATION_MS,
      players
    )
    .catch(
      (err): PlaytestEndResult => ({
        playtestId,
        success: false,
        error: err instanceof Error ? err.message : String(err),
      })
    );

  const clientCount = players ?? (mode === 'play' ? 1 : 0);
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
    throw new Error(
      outcome.result.success
        ? 'Playtest ended before its sessions connected'
        : `Playtest failed to start: ${outcome.result.error}`
    );
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
    throw new Error(
      `Playtest started, but ${waited}, so stop it in Studio. Play sessions only connect with Studio's "Load user plugins on playtest" setting on.`
    );
  }

  await endPlaytestAsync(connection, server);
  throw new Error(`Playtest started, but ${waited}, so it was stopped.`);
}

async function assertCanStartMultiplayerAsync(
  editSession: BridgeSession,
  mode: PlaytestMode,
  players: number
): Promise<void> {
  if (!Number.isInteger(players) || players < 1) {
    throw new Error(
      `--players must be a whole number of at least 1, not ${players}`
    );
  }
  if (mode !== 'play') {
    throw new Error('A multiplayer test runs in play mode');
  }

  // Older plugins give every client the same session id, so all but one drop off
  const expected = await getPluginBuildVersionAsync();
  if (editSession.info.pluginVersion !== expected) {
    throw new Error(
      `Multiplayer tests need the current studio-bridge plugin, but '${editSession.info.placeName}' has an older one. Run 'studio-bridge plugin install' first.`
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
      if (err instanceof ContextNotFoundError) {
        throw new Error(`No playtest of '${target}' is running`);
      }
      throw err;
    }
  }

  const servers = connection
    .listSessions()
    .filter((info) => info.context === 'server');
  if (servers.length === 0) {
    throw new Error('No playtest is running');
  }
  if (servers.length > 1) {
    const list = servers
      .map((info) => `  - ${info.sessionId}: ${info.placeName}`)
      .join('\n');
    throw new Error(
      `Multiple playtests are running. Use --target <id> to pick a server session.\n${list}`
    );
  }

  const session = connection.getSession(servers[0].sessionId);
  if (!session) {
    throw new Error(`Session '${servers[0].sessionId}' disconnected`);
  }
  return session;
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
    const checked = new Set<string>();

    const cleanup = () => {
      clearTimeout(timer);
      connection.off('session-connected', onSession);
      signal.removeEventListener('abort', cleanup);
    };

    const onSession = (session: BridgeSession) => {
      const { sessionId } = session.info;
      if (session.context === 'edit' || checked.has(sessionId)) {
        return;
      }
      checked.add(sessionId);

      void readPlaytestIdAsync(connection, sessionId, signal).then((read) => {
        if (signal.aborted || !read) return;
        if (read.id !== playtestId) {
          // The last playtest's session can linger under the same id; read its replacement too
          checked.delete(sessionId);
          return;
        }

        if (read.session.context === 'server') {
          found.server = read.session;
        } else {
          found.clients.push(read.session);
        }
        if (found.server && found.clients.length >= clientCount) {
          cleanup();
          resolve(found);
        }
      });
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

/**
 * Reads the playtest id a session was started under, retrying while the read
 * fails: a playtest's DataModels are slow to answer while their Studio boots,
 * and a session that reconnects is read again under the same id.
 */
async function readPlaytestIdAsync(
  connection: BridgeConnection,
  sessionId: string,
  signal: AbortSignal
): Promise<{ session: BridgeSession; id: string | undefined } | undefined> {
  while (!signal.aborted) {
    const session = connection.getSession(sessionId);
    if (session) {
      try {
        const result = await session.execAsync(READ_PLAYTEST_ID_SCRIPT, 5_000);
        if (result.success) {
          const value = result.returnValues?.[0];
          return { session, id: typeof value === 'string' ? value : undefined };
        }
      } catch {
        // Retried below
      }
    }
    await new Promise((resolve) => setTimeout(resolve, READ_RETRY_DELAY_MS));
  }
  return undefined;
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
        new Error(
          `Playtest did not close within ${SESSION_CLOSE_TIMEOUT_MS / 1000}s`
        )
      );
    }, SESSION_CLOSE_TIMEOUT_MS);

    connection.on('session-disconnected', onDisconnected);
  });
}
