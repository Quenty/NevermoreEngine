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

/** How long a started playtest may run before its pending start request is dropped. */
const PLAYTEST_MAX_DURATION_MS = 24 * 60 * 60 * 1000;

const SESSION_WAIT_TIMEOUT_MS = 30_000;
const SESSION_CLOSE_TIMEOUT_MS = 10_000;

const READ_PLAYTEST_ID_SCRIPT = [
  'local ok, args = pcall(function()',
  '\treturn game:GetService("StudioTestService"):GetTestArgs()',
  'end)',
  'return if ok and type(args) == "table" then args.studioBridgePlaytestId else nil',
].join('\n');

export interface StartedPlaytest {
  playtestId: string;
  mode: PlaytestMode;
  /** The playtest's sessions: always `server`, plus `client` in play mode. */
  sessions: Partial<Record<SessionContext, BridgeSession>>;
  /** Settles when the playtest ends. Never rejects. */
  ended: Promise<PlaytestEndResult>;
}

/** The sessions a playtest opens, by mode. Run mode has no player, so no client. */
export function getPlaytestContexts(mode: PlaytestMode): SessionContext[] {
  return mode === 'play' ? ['server', 'client'] : ['server'];
}

/**
 * Start a playtest from `editSession` and resolve once every session it opens
 * has connected. Rejects if Studio refuses to start it, e.g. because a
 * playtest is already running.
 */
export async function startPlaytestAsync(
  connection: BridgeConnection,
  editSession: BridgeSession,
  mode: PlaytestMode
): Promise<StartedPlaytest> {
  if (editSession.context !== 'edit') {
    throw new Error(
      `Playtests start from an edit session, but '${editSession.info.sessionId}' is a ${editSession.context} session`
    );
  }

  const playtestId = randomUUID();
  const ended = editSession
    .runPlaytestAsync(
      mode,
      playtestId,
      connection.port,
      PLAYTEST_MAX_DURATION_MS
    )
    .catch(
      (err): PlaytestEndResult => ({
        playtestId,
        success: false,
        error: err instanceof Error ? err.message : String(err),
      })
    );

  const contexts = getPlaytestContexts(mode);
  const abort = new AbortController();
  let outcome;
  try {
    outcome = await Promise.race([
      waitForPlaytestSessionsAsync(
        connection,
        playtestId,
        contexts,
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

  const { sessions } = outcome;
  const missing = contexts.filter((context) => !sessions[context]);
  if (missing.length === 0) {
    return { playtestId, mode, sessions, ended };
  }

  const waited = `its ${missing.join(' and ')} session did not connect within ${
    SESSION_WAIT_TIMEOUT_MS / 1000
  }s`;

  // Without its server session the playtest can't be ended from here
  if (!sessions.server?.isConnected) {
    throw new Error(
      `Playtest started, but ${waited}, so stop it in Studio. Play sessions only connect with Studio's "Load user plugins on playtest" setting on.`
    );
  }

  await endPlaytestAsync(connection, sessions.server);
  throw new Error(`Playtest started, but ${waited}, so it was stopped.`);
}

/**
 * Resolve the server session of a running playtest. `target` names it
 * directly; otherwise there must be exactly one server session connected.
 */
export async function resolvePlaytestServerSessionAsync(
  connection: BridgeConnection,
  target?: string
): Promise<BridgeSession> {
  if (target) {
    const session = await connection.resolveSessionAsync(target);
    if (session.context !== 'server') {
      throw new Error(
        `Session '${target}' is a ${session.context} session; a playtest is ended from its server session`
      );
    }
    return session;
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

async function waitForPlaytestSessionsAsync(
  connection: BridgeConnection,
  playtestId: string,
  contexts: SessionContext[],
  signal: AbortSignal
): Promise<Partial<Record<SessionContext, BridgeSession>>> {
  return new Promise((resolve) => {
    const found: Partial<Record<SessionContext, BridgeSession>> = {};
    const checked = new Set<string>();

    const cleanup = () => {
      clearTimeout(timer);
      connection.off('session-connected', onSession);
      signal.removeEventListener('abort', cleanup);
    };

    const onSession = (session: BridgeSession) => {
      const { sessionId } = session.info;
      if (
        !contexts.includes(session.context) ||
        found[session.context] ||
        checked.has(sessionId)
      ) {
        return;
      }
      checked.add(sessionId);

      void tryReadPlaytestIdAsync(session).then((id) => {
        if (signal.aborted || id !== playtestId) return;

        found[session.context] = session;
        if (contexts.every((context) => found[context])) {
          cleanup();
          resolve(found);
        }
      });
    };

    // Resolves with whichever sessions connected; the caller reports the rest
    const timer = setTimeout(() => {
      cleanup();
      resolve(found);
    }, SESSION_WAIT_TIMEOUT_MS);

    signal.addEventListener('abort', cleanup);
    connection.on('session-connected', onSession);

    for (const info of connection.listSessions()) {
      const session = connection.getSession(info.sessionId);
      if (session) onSession(session);
    }
  });
}

/** Returns the playtest id a session was started under, if any. */
async function tryReadPlaytestIdAsync(
  session: BridgeSession
): Promise<string | undefined> {
  try {
    const result = await session.execAsync(READ_PLAYTEST_ID_SCRIPT, 5_000);
    const value = result.returnValues?.[0];
    return typeof value === 'string' ? value : undefined;
  } catch {
    return undefined;
  }
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
