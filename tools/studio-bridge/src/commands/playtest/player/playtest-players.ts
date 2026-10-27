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

const PLAYER_CHANGE_TIMEOUT_SEC = 60;
const CLIENT_SESSION_TIMEOUT_MS = 30_000;
const SCRIPT_GRACE_MS = 10_000;

export interface PlaytestPlayer {
  name: string;
  userId: number;
  displayName: string;
  /** The player's client session, when it is connected. */
  sessionId?: string;
}

const PLAYER_INFO_FUNCTION = [
  'local function playerInfo(player)',
  '\treturn { name = player.Name, userId = player.UserId, displayName = player.DisplayName }',
  'end',
].join('\n');

const LIST_PLAYERS_SCRIPT = [
  PLAYER_INFO_FUNCTION,
  'local players = {}',
  'for _, player in game:GetService("Players"):GetPlayers() do',
  '\ttable.insert(players, playerInfo(player))',
  'end',
  'return players',
].join('\n');

function addPlayersScript(count: number): string {
  return [
    PLAYER_INFO_FUNCTION,
    'local Players = game:GetService("Players")',
    'local before = {}',
    'for _, player in Players:GetPlayers() do',
    '\tbefore[player] = true',
    'end',
    `game:GetService("StudioTestService"):AddPlayers(${count})`,
    `local deadline = os.clock() + ${PLAYER_CHANGE_TIMEOUT_SEC}`,
    'local added = {}',
    'repeat',
    '\ttask.wait(0.25)',
    '\tadded = {}',
    '\tfor _, player in Players:GetPlayers() do',
    '\t\tif not before[player] then',
    '\t\t\ttable.insert(added, playerInfo(player))',
    '\t\tend',
    '\tend',
    `until #added >= ${count} or os.clock() > deadline`,
    'return added',
  ].join('\n');
}

function kickPlayersScript(names: string[]): string {
  return [
    `local names = ${luaStringList(names)}`,
    'local Players = game:GetService("Players")',
    'for _, name in names do',
    '\tlocal player = Players:FindFirstChild(name)',
    '\tif player then',
    '\t\tplayer:Kick("Removed by studio-bridge")',
    '\tend',
    'end',
  ].join('\n');
}

function waitForPlayersGoneScript(names: string[]): string {
  return [
    `local names = ${luaStringList(names)}`,
    'local Players = game:GetService("Players")',
    `local deadline = os.clock() + ${PLAYER_CHANGE_TIMEOUT_SEC}`,
    'local remaining',
    'repeat',
    '\tremaining = {}',
    '\tfor _, name in names do',
    '\t\tif Players:FindFirstChild(name) then',
    '\t\t\ttable.insert(remaining, name)',
    '\t\tend',
    '\tend',
    '\tif #remaining > 0 then',
    '\t\ttask.wait(0.25)',
    '\tend',
    'until #remaining == 0 or os.clock() > deadline',
    'return remaining',
  ].join('\n');
}

const LEAVE_TEST_SCRIPT =
  'task.defer(function() game:GetService("StudioTestService"):LeaveTest() end)';

function luaStringList(values: string[]): string {
  return `{ ${values.map((value) => JSON.stringify(value)).join(', ')} }`;
}

async function runScriptAsync(
  session: BridgeSession,
  script: string
): Promise<unknown> {
  const result = await session.execAsync(
    script,
    PLAYER_CHANGE_TIMEOUT_SEC * 1000 + SCRIPT_GRACE_MS
  );
  if (!result.success) {
    throw new Error(result.error ?? 'Player script failed');
  }
  return result.returnValues?.[0];
}

function toPlayers(value: unknown): PlaytestPlayer[] {
  if (!Array.isArray(value)) return [];
  return value.map((entry) => ({
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
  const players = toPlayers(
    await runScriptAsync(serverSession, LIST_PLAYERS_SCRIPT)
  );
  return withSessions(connection, serverSession.info.instanceId, players);
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
    await runScriptAsync(serverSession, addPlayersScript(count))
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
  const targets = names.map((name) => {
    const player = current.find(
      (p) => p.name.toLowerCase() === name.toLowerCase()
    );
    if (!player) {
      const known = current.map((p) => p.name).join(', ') || 'none';
      throw new Error(`No player named '${name}' (players: ${known})`);
    }
    return player;
  });

  const removed: RemovedPlayer[] = [];
  const toKick: string[] = [];
  for (const player of targets) {
    const client = player.sessionId
      ? connection.getSession(player.sessionId)
      : undefined;
    if (client) {
      await runScriptAsync(client, LEAVE_TEST_SCRIPT);
      removed.push({ name: player.name, how: 'left' });
    } else {
      toKick.push(player.name);
      removed.push({ name: player.name, how: 'kicked' });
    }
  }
  if (toKick.length > 0) {
    await runScriptAsync(serverSession, kickPlayersScript(toKick));
  }

  const remaining = await runScriptAsync(
    serverSession,
    waitForPlayersGoneScript(targets.map((p) => p.name))
  );
  if (Array.isArray(remaining) && remaining.length > 0) {
    throw new Error(
      `Players still in the playtest after ${PLAYER_CHANGE_TIMEOUT_SEC}s: ${remaining.join(
        ', '
      )}`
    );
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
