import { describe, it, expect, vi } from 'vitest';
import {
  addPlaytestPlayersAsync,
  listPlaytestPlayersAsync,
  removePlaytestPlayersAsync,
} from './playtest-players.js';

function createSession(
  sessionId: string,
  context: string,
  returnValues: unknown[][],
  playerName?: string
) {
  const scripts: string[] = [];
  return {
    scripts,
    info: { sessionId, instanceId: 'place-1a2b', context, playerName },
    context,
    execAsync: vi.fn(async (script: string) => {
      scripts.push(script);
      return { success: true, output: [], returnValues: returnValues.shift() };
    }),
  };
}

function createConnection(sessions: Array<ReturnType<typeof createSession>>) {
  return {
    listSessions: () => sessions.map((s) => s.info),
    getSession: (id: string) => sessions.find((s) => s.info.sessionId === id),
  } as any;
}

const player = (name: string, userId: number) => ({
  name,
  userId,
  displayName: name,
});

describe('listPlaytestPlayersAsync', () => {
  it('pairs each player with its client session', async () => {
    const server = createSession('place-1a2b-server', 'server', [
      [[player('Player1', -1), player('Player2', -2)]],
    ]);
    const client = createSession(
      'place-1a2b-client-player1',
      'client',
      [],
      'Player1'
    );

    const players = await listPlaytestPlayersAsync(
      createConnection([server, client]),
      server as any
    );

    expect(players).toEqual([
      { ...player('Player1', -1), sessionId: 'place-1a2b-client-player1' },
      player('Player2', -2),
    ]);
  });
});

describe('addPlaytestPlayersAsync', () => {
  it('adds players from the server and reports the ones that joined', async () => {
    const server = createSession('place-1a2b-server', 'server', [
      [[player('Player3', -3)]],
    ]);
    const client = createSession(
      'place-1a2b-client-player3',
      'client',
      [],
      'Player3'
    );

    const players = await addPlaytestPlayersAsync(
      createConnection([server, client]),
      server as any,
      1
    );

    expect(server.scripts[0]).toContain('AddPlayers(1)');
    expect(players).toEqual([
      { ...player('Player3', -3), sessionId: 'place-1a2b-client-player3' },
    ]);
  });
});

describe('removePlaytestPlayersAsync', () => {
  it('has a connected client leave and kicks the rest', async () => {
    const server = createSession('place-1a2b-server', 'server', [
      [[player('Player1', -1), player('Player2', -2)]],
      [],
      [[]],
    ]);
    const client = createSession(
      'place-1a2b-client-player1',
      'client',
      [[]],
      'Player1'
    );

    const removed = await removePlaytestPlayersAsync(
      createConnection([server, client]),
      server as any,
      ['player1', 'Player2']
    );

    expect(removed).toEqual([
      { name: 'Player1', how: 'left' },
      { name: 'Player2', how: 'kicked' },
    ]);
    expect(client.scripts[0]).toContain('LeaveTest');
    expect(server.scripts[1]).toContain('"Player2"');
    expect(server.scripts[1]).not.toContain('"Player1"');
  });

  it('removes a player named twice only once', async () => {
    const server = createSession('place-1a2b-server', 'server', [
      [[player('Player2', -2)]],
      [],
      [[]],
    ]);

    const removed = await removePlaytestPlayersAsync(
      createConnection([server]),
      server as any,
      ['Player2', 'player2']
    );

    expect(removed).toEqual([{ name: 'Player2', how: 'kicked' }]);
  });

  it('refuses an unknown name before removing anyone', async () => {
    const server = createSession('place-1a2b-server', 'server', [
      [[player('Player1', -1)]],
    ]);

    await expect(
      removePlaytestPlayersAsync(createConnection([server]), server as any, [
        'Player1',
        'Nobody',
      ])
    ).rejects.toThrow("No player named 'Nobody' (players: Player1)");
    expect(server.scripts).toHaveLength(1);
  });
});
