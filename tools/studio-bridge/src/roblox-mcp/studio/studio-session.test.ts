import { describe, expect, it } from 'vitest';
import type { SessionInfo } from '../../bridge/types.js';
import { McpStdioClient } from '../mcp/mcp-stdio-client.js';
import { createFakeMcpServer, toolText } from '../test/fake-mcp-server.js';
import {
  cleanToolError,
  matchStudiosAsync,
  resolveStudio,
  runLuauAsync,
  type MatchedStudio,
} from './studio-session.js';

interface FakeStudio {
  id: string;
  name: string;
  placeId: number;
  gameId: number;
  uptime?: number;
}

async function startAsync(studios: FakeStudio[]) {
  const server = createFakeMcpServer((method, params) => {
    if (method === 'initialize') {
      return { result: { protocolVersion: '2025-06-18', capabilities: {} } };
    }
    if (params?.name === 'list_roblox_studios') {
      return toolText(
        JSON.stringify({
          studios: studios.map(({ id, name }) => ({ id, name })),
        })
      );
    }
    if (params?.name === 'execute_luau') {
      const studio = studios.find((s) => s.id === params.arguments.studio_id);
      if (params.arguments.datamodel_type !== 'Edit') {
        return toolText(
          `${params.arguments.datamodel_type} datamodel is not available in Edit mode`,
          true
        );
      }
      return studio
        ? toolText(`${studio.uptime ?? 0},${studio.placeId},${studio.gameId}`)
        : toolText('not connected', true);
    }
    return undefined;
  });
  const client = await McpStdioClient.startAsync('StudioMCP.exe', {
    spawnProcess: () => server.child,
  });
  return { server, client };
}

function session(overrides: Partial<SessionInfo>): SessionInfo {
  return {
    sessionId: 'place1-aaaa-edit',
    instanceId: 'place1-aaaa',
    placeName: 'Place1',
    state: 'Edit',
    pluginVersion: '1',
    capabilities: [],
    connectedAt: new Date(0),
    origin: 'user',
    context: 'edit',
    placeId: 0,
    gameId: 0,
    ...overrides,
  };
}

const luauCalls = (server: { requests: Array<{ params: any }> }) =>
  server.requests.filter((r) => r.params?.name === 'execute_luau').length;

describe('matchStudiosAsync', () => {
  it('matches a uniquely named Studio to its session without running anything', async () => {
    const { server, client } = await startAsync([
      { id: 'mcp-1', name: 'Place1', placeId: 0, gameId: 0 },
    ]);

    const [studio] = await matchStudiosAsync(
      client,
      [session({})],
      [{ pid: 7, windowTitle: 'Place1 - Roblox Studio' }]
    );

    expect(studio).toMatchObject({
      studioId: 'mcp-1',
      sessionId: 'place1-aaaa-edit',
      instanceId: 'place1-aaaa',
      pid: 7,
    });
    expect(luauCalls(server)).toBe(0);
    await client.closeAsync();
  });

  it('tells same-named Studios apart by place id', async () => {
    const { client } = await startAsync([
      { id: 'mcp-1', name: 'Game', placeId: 111, gameId: 1 },
      { id: 'mcp-2', name: 'Game', placeId: 222, gameId: 2 },
    ]);

    const studios = await matchStudiosAsync(client, [
      session({
        sessionId: 'a-edit',
        instanceId: 'a',
        placeName: 'Game',
        placeId: 222,
      }),
      session({
        sessionId: 'b-edit',
        instanceId: 'b',
        placeName: 'Game',
        placeId: 111,
      }),
    ]);

    expect(studios.map((s) => [s.studioId, s.sessionId])).toEqual([
      ['mcp-1', 'b-edit'],
      ['mcp-2', 'a-edit'],
    ]);
    await client.closeAsync();
  });

  it('leaves two unsaved places with the same name unmatched rather than guess', async () => {
    const { client } = await startAsync([
      { id: 'mcp-1', name: 'Place1', placeId: 0, gameId: 0 },
      { id: 'mcp-2', name: 'Place1', placeId: 0, gameId: 0 },
    ]);

    const studios = await matchStudiosAsync(client, [
      session({ sessionId: 'a-edit' }),
      session({ sessionId: 'b-edit' }),
    ]);

    expect(studios.every((s) => s.sessionId === undefined)).toBe(true);
    await client.closeAsync();
  });

  it('reads place ids for a Studio the bridge has no session for', async () => {
    const { client } = await startAsync([
      { id: 'mcp-1', name: 'Hub', placeId: 333, gameId: 3 },
    ]);

    const [studio] = await matchStudiosAsync(client, []);

    expect(studio).toMatchObject({
      studioId: 'mcp-1',
      placeId: 333,
      gameId: 3,
    });
    expect(studio.sessionId).toBeUndefined();
    await client.closeAsync();
  });
});

describe('cleanToolError', () => {
  it("drops the Assistant's own frames from an execute_luau error", () => {
    expect(
      cleanToolError(
        'sabuiltin_Assistant.rbxm.Assistant.Packages._Index.AssistantUI.AssistantUI.Tools.ExecuteLuauTool:125: sabuiltin_Assistant.rbxm.Assistant.Packages._Index.AssistantUI.AssistantUI.Util.CommandExecution:54: AssistantCommand:1: boom'
      )
    ).toBe('boom');
  });

  it('leaves other errors alone', () => {
    expect(
      cleanToolError('Server datamodel is not available in Edit mode')
    ).toBe('Server datamodel is not available in Edit mode');
  });
});

describe('resolveStudio', () => {
  const studios: MatchedStudio[] = [
    {
      studioId: '1268b6c6-aaaa',
      placeName: 'Place1',
      sessionId: 'place1-3d83-edit',
      instanceId: 'place1-3d83',
      pid: 10,
    },
    { studioId: '99f00000-bbbb', placeName: 'Hub' },
  ];

  it('picks the only Studio without a target', () => {
    expect(resolveStudio([studios[1]]).studioId).toBe('99f00000-bbbb');
  });

  it('asks for --target when several are open', () => {
    expect(() => resolveStudio(studios)).toThrow('Pick one with --target');
  });

  it.each([
    ['a bridge session id', 'place1-3d83-edit'],
    ['a bridge instance id', 'place1-3d83'],
    ['an instance id prefix', 'place1'],
    ['an MCP studio id prefix', '1268b6c6'],
    ['a pid', '10'],
  ])('resolves %s', (_label, target) => {
    expect(resolveStudio(studios, target).studioId).toBe('1268b6c6-aaaa');
  });

  it('resolves a place name for a Studio the bridge has no session for', () => {
    expect(resolveStudio(studios, 'hub').studioId).toBe('99f00000-bbbb');
  });

  it('names the open Studios when nothing matches', () => {
    expect(() => resolveStudio(studios, 'nope')).toThrow(
      "No Studio matches 'nope'"
    );
  });
});

describe('runLuauAsync', () => {
  it('maps a bridge context to the MCP data model and reports its error', async () => {
    const { server, client } = await startAsync([
      { id: 'mcp-1', name: 'Place1', placeId: 0, gameId: 0 },
    ]);

    const result = await runLuauAsync(client, 'mcp-1', 'return 1', 'server');

    expect(server.requests.at(-1)?.params.arguments.datamodel_type).toBe(
      'Server'
    );
    expect(result).toEqual({
      success: false,
      error: 'Server datamodel is not available in Edit mode',
    });
    await client.closeAsync();
  });
});

describe('matchStudiosAsync by uptime', () => {
  it('tells same-named unsaved Studios apart by how long each has run', async () => {
    const now = Date.now();
    const { client } = await startAsync([
      { id: 'mcp-old', name: 'Place1', placeId: 0, gameId: 0, uptime: 300 },
      { id: 'mcp-new', name: 'Place1', placeId: 0, gameId: 0, uptime: 290 },
    ]);
    const windows = [
      {
        pid: 70,
        windowTitle: 'Place1 - Roblox Studio',
        startedAt: now - 300_000,
      },
      {
        pid: 80,
        windowTitle: 'Place1 - Roblox Studio',
        startedAt: now - 290_000,
      },
    ];

    const studios = await matchStudiosAsync(
      client,
      [
        session({ sessionId: 'a-edit', instanceId: 'a' }),
        session({ sessionId: 'b-edit', instanceId: 'b' }),
      ],
      windows,
      {
        sessionPids: new Map([
          ['a', 80],
          ['b', 70],
        ]),
      }
    );

    expect(studios.map((s) => [s.studioId, s.pid, s.sessionId])).toEqual([
      ['mcp-old', 70, 'b-edit'],
      ['mcp-new', 80, 'a-edit'],
    ]);
    await client.closeAsync();
  });

  it('never gives one session to two Studios', async () => {
    const { client } = await startAsync([
      { id: 'mcp-1', name: 'Place1', placeId: 0, gameId: 0 },
      { id: 'mcp-2', name: 'Place1', placeId: 0, gameId: 0 },
    ]);

    const studios = await matchStudiosAsync(client, [session({})]);

    expect(studios.filter((s) => s.sessionId).length).toBe(0);
    await client.closeAsync();
  });
});
