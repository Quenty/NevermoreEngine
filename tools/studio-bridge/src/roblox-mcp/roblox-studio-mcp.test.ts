import { describe, expect, it } from 'vitest';
import {
  tryCallStudioToolAsync,
  tryExecuteLuauAsync,
  tryListStudiosAsync,
} from './roblox-studio-mcp.js';
import {
  createFakeMcpServer,
  toolText,
  type FakeHandler,
} from './test/fake-mcp-server.js';

const STUDIOS = [
  { id: 'mcp-1', name: 'Place1' },
  { id: 'mcp-2', name: 'Hub' },
];

function fake(handler: FakeHandler = () => undefined, studios = STUDIOS) {
  const server = createFakeMcpServer((method, params) => {
    if (method === 'initialize') {
      return { result: { protocolVersion: '2025-06-18', capabilities: {} } };
    }
    if (params?.name === 'list_roblox_studios') {
      return toolText(JSON.stringify({ studios }));
    }
    if (
      params?.name === 'execute_luau' &&
      params.arguments.code.includes('game.PlaceId')
    ) {
      return toolText('0,0');
    }
    return handler(method, params);
  });
  return {
    server,
    options: {
      executablePath: 'StudioMCP.exe',
      spawnProcess: () => server.child,
      listWindowsAsync: async () => [],
    },
  };
}

describe('tryExecuteLuauAsync', () => {
  it('runs Luau in the targeted Studio and returns its result', async () => {
    const { server, options } = fake((_method, params) =>
      params?.name === 'execute_luau' ? toolText('42') : undefined
    );

    const result = await tryExecuteLuauAsync('return 42', {
      ...options,
      target: 'hub',
    });

    expect(result).toMatchObject({ success: true, value: '42' });
    expect(server.requests.at(-1)?.params.arguments).toEqual({
      code: 'return 42',
      studio_id: 'mcp-2',
      datamodel_type: 'Edit',
    });
  });

  it('sends the context as the data model', async () => {
    const { server, options } = fake(() => toolText('ok'));

    await tryExecuteLuauAsync('return 1', {
      ...options,
      target: 'hub',
      context: 'server',
    });

    expect(server.requests.at(-1)?.params.arguments.datamodel_type).toBe(
      'Server'
    );
  });

  it('fails with the script error, naming the Studio', async () => {
    const { options } = fake(() => toolText('boom', true));

    const result = await tryExecuteLuauAsync('error("boom")', {
      ...options,
      target: 'hub',
    });

    expect(result).toMatchObject({
      success: false,
      reason: 'failed',
      message: 'boom',
      studio: { studioId: 'mcp-2' },
    });
  });

  it('fails with no-studio when the target is ambiguous', async () => {
    const { options } = fake();

    const result = await tryExecuteLuauAsync('return 1', options);

    expect(result).toMatchObject({ success: false, reason: 'no-studio' });
  });

  it('fails with unavailable when the server exits before answering', async () => {
    const server = createFakeMcpServer(() => undefined);
    server.exit(1, 'no Studio');

    const result = await tryExecuteLuauAsync('return 1', {
      executablePath: 'StudioMCP.exe',
      spawnProcess: () => server.child,
      listWindowsAsync: async () => [],
    });

    expect(result).toMatchObject({ success: false, reason: 'unavailable' });
    expect(result.success || result.message).toContain('no Studio');
  });

  it('fails with timeout when the whole call outlives its deadline', async () => {
    const { server, options } = fake(() => undefined);

    const started = Date.now();
    const result = await tryExecuteLuauAsync('return 1', {
      ...options,
      target: 'hub',
      timeoutMs: 50,
    });

    expect(result).toMatchObject({ success: false, reason: 'timeout' });
    expect(Date.now() - started).toBeLessThan(1000);
    expect(server.child.killed).toBe(true);
  });

  it('fails with timeout when the tool never answers', async () => {
    const { options } = fake(() => undefined);

    const result = await tryExecuteLuauAsync('return 1', {
      ...options,
      target: 'hub',
      timeoutMs: 20,
    });

    expect(result).toMatchObject({ success: false, reason: 'timeout' });
  });
});

describe('tryCallStudioToolAsync', () => {
  it('fills in the studio id and leaves other tools without a data model', async () => {
    const { server, options } = fake(() => toolText('Edit'));

    const result = await tryCallStudioToolAsync(
      'get_studio_state',
      {},
      {
        ...options,
        target: 'place1',
      }
    );

    expect(result).toMatchObject({ success: true, value: 'Edit' });
    expect(server.requests.at(-1)?.params).toEqual({
      name: 'get_studio_state',
      arguments: { studio_id: 'mcp-1' },
    });
  });
});

describe('tryListStudiosAsync', () => {
  it('lists the open Studios', async () => {
    const { options } = fake();

    const result = await tryListStudiosAsync(options);

    expect(result.success && result.value.map((s) => s.placeName)).toEqual([
      'Place1',
      'Hub',
    ]);
  });
});
