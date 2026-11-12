/**
 * The players of a running playtest, read and changed through its server
 * session.
 *
 * StudioTestService only adds players from the server DataModel of a
 * multiplayer test, and each player is a client in its own Studio process.
 * Kicking a player leaves that process open, so a player whose client
 * session is connected leaves through `LeaveTest` instead, which closes it.
 */

import type { BridgeConnection, BridgeSession } from '../../../bridge/index.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatTable,
  type TableColumn,
} from '@quenty/cli-output-helpers/reporting';
import { StudioBridgeError } from '../../../messages/studio-bridge-error.js';

const PLAYER_CHANGE_TIMEOUT_SEC = 60;
const CLIENT_SESSION_TIMEOUT_MS = 30_000;
const REPLY_GRACE_MS = 10_000;

export interface PlaytestPlayer {
  name: string;
  userId: number;
  displayName: string;
  /** The player's client session, when it is connected. */
  sessionId?: string;
}

const REQUEST_TIMEOUT_MS = PLAYER_CHANGE_TIMEOUT_SEC * 1000 + REPLY_GRACE_MS;

function toPlayers(
  players: Array<{ name: string; userId: number; displayName: string }>
): PlaytestPlayer[] {
  return players.map((entry) => ({
    name: String(entry.name),
    userId: Number(entry.userId),
    displayName: String(entry.displayName),
  }));
}

function findClientSession(
  connection: BridgeConnection,
  instanceId: string,
  playerName: string
): BridgeSession | undefined {
  const info = connection
    .listSessions()
    .find(
      (s) =>
        s.instanceId === instanceId &&
        s.context === 'client' &&
        s.playerName === playerName
    );
  return info ? connection.getSession(info.sessionId) : undefined;
}

function withSessions(
  connection: BridgeConnection,
  instanceId: string,
  players: PlaytestPlayer[]
): PlaytestPlayer[] {
  return players.map((player) => {
    const session = findClientSession(connection, instanceId, player.name);
    return session ? { ...player, sessionId: session.info.sessionId } : player;
  });
}

/** The players in the playtest `serverSession` belongs to. */
export async function listPlaytestPlayersAsync(
  connection: BridgeConnection,
  serverSession: BridgeSession
): Promise<PlaytestPlayer[]> {
  const { players } = await serverSession.playtestPlayersAsync(
    { op: 'list' },
    REQUEST_TIMEOUT_MS
  );
  return withSessions(
    connection,
    serverSession.info.instanceId,
    toPlayers(players)
  );
}

/**
 * Add `count` players to a multiplayer test, resolving with them once they
 * have joined and their client sessions have connected, or after a timeout.
 */
export async function addPlaytestPlayersAsync(
  connection: BridgeConnection,
  serverSession: BridgeSession,
  count: number
): Promise<PlaytestPlayer[]> {
  const added = toPlayers(
    (
      await serverSession.playtestPlayersAsync(
        { op: 'add', count, timeoutSec: PLAYER_CHANGE_TIMEOUT_SEC },
        REQUEST_TIMEOUT_MS
      )
    ).players
  );
  const { instanceId } = serverSession.info;

  const deadline = Date.now() + CLIENT_SESSION_TIMEOUT_MS;
  while (
    Date.now() < deadline &&
    added.some(
      (player) => !findClientSession(connection, instanceId, player.name)
    )
  ) {
    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  return withSessions(connection, instanceId, added);
}

export interface RemovedPlayer {
  name: string;
  /** `left` closed the player's client; `kicked` leaves its window open. */
  how: 'left' | 'kicked';
}

/**
 * Remove players by name, case-insensitively, resolving once they are gone.
 * Throws for a name that is not in the playtest, before removing anyone.
 */
export async function removePlaytestPlayersAsync(
  connection: BridgeConnection,
  serverSession: BridgeSession,
  names: string[]
): Promise<RemovedPlayer[]> {
  const current = await listPlaytestPlayersAsync(connection, serverSession);
  const found = names.map((name) => {
    const player = current.find(
      (p) => p.name.toLowerCase() === name.toLowerCase()
    );
    if (!player) {
      const known = current.map((p) => p.name).join(', ') || 'none';
      throw new StudioBridgeError({
        code: 'PLAYER_NOT_FOUND',
        message: `No player named '${name}' is in the playtest, so nobody was removed.`,
        fix: `Use one of: ${known}.`,
      });
    }
    return player;
  });
  const targets = [...new Set(found)];

  const removed: RemovedPlayer[] = [];
  const toKick: string[] = [];
  for (const player of targets) {
    const client = player.sessionId
      ? connection.getSession(player.sessionId)
      : undefined;
    if (client) {
      await client.playtestPlayersAsync({ op: 'leave' }, REQUEST_TIMEOUT_MS);
      removed.push({ name: player.name, how: 'left' });
    } else {
      toKick.push(player.name);
      removed.push({ name: player.name, how: 'kicked' });
    }
  }
  const { remaining } = await serverSession.playtestPlayersAsync(
    {
      op: 'remove',
      kick: toKick,
      names: targets.map((p) => p.name),
      timeoutSec: PLAYER_CHANGE_TIMEOUT_SEC,
    },
    REQUEST_TIMEOUT_MS
  );
  if (remaining.length > 0) {
    throw new StudioBridgeError({
      code: 'PLAYERS_STILL_IN_PLAYTEST',
      message: `${remaining.join(', ')} ${
        remaining.length === 1 ? 'is' : 'are'
      } still in the playtest after ${PLAYER_CHANGE_TIMEOUT_SEC}s.`,
      fix: 'Run the command again, or close their client windows in Studio.',
    });
  }
  return removed;
}

const playerColumns: TableColumn<PlaytestPlayer>[] = [
  { header: 'Player', value: (p) => p.name },
  { header: 'UserId', value: (p) => String(p.userId) },
  {
    header: 'Session',
    value: (p) => p.sessionId ?? '',
    format: (v) => OutputHelper.formatHint(v),
  },
];

export function formatPlayersTable(players: PlaytestPlayer[]): string {
  return formatTable(players, playerColumns);
}
