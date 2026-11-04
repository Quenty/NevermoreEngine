import { describe, expect, it } from 'vitest';
import { McpStdioClient } from './mcp-stdio-client.js';
import {
  createFakeMcpServer,
  toolText,
  type FakeHandler,
} from '../test/fake-mcp-server.js';

const initialize: FakeHandler = (method) =>
  method === 'initialize'
    ? {
        result: {
          protocolVersion: '2025-06-18',
          capabilities: { tools: {} },
          serverInfo: { name: 'RobloxStudio', version: '1.0.0' },
        },
      }
    : undefined;

async function startAsync(handler: FakeHandler, requestTimeoutMs?: number) {
  const server = createFakeMcpServer(
    (method, params) => initialize(method, params) ?? handler(method, params)
  );
  const client = await McpStdioClient.startAsync('StudioMCP.exe', {
    spawnProcess: () => server.child,
    requestTimeoutMs,
  });
  return { server, client };
}

describe('McpStdioClient', () => {
  it('initializes, then says it is initialized', async () => {
    const { server, client } = await startAsync(() => undefined);

    expect(client.protocolVersion).toBe('2025-06-18');
    expect(client.serverInfo?.name).toBe('RobloxStudio');
    expect(server.requests.map((r) => r.method)).toEqual([
      'initialize',
      'notifications/initialized',
    ]);
    await client.closeAsync();
  });

  it('lists tools, repairing a list result without caching hints', async () => {
    const { client } = await startAsync((method) =>
      method === 'tools/list'
        ? {
            result: {
              resultType: 'complete',
              tools: [{ name: 'execute_luau' }],
            },
          }
        : undefined
    );

    expect(await client.listToolsAsync()).toEqual([{ name: 'execute_luau' }]);
    await expect(client.requestAsync('tools/list', {})).resolves.toMatchObject({
      ttlMs: 0,
      cacheScope: 'private',
    });
    await client.closeAsync();
  });

  it('calls a tool and joins its text content', async () => {
    const { server, client } = await startAsync((method) =>
      method === 'tools/call' ? toolText('42') : undefined
    );

    const result = await client.callToolAsync('execute_luau', { code: 'x' });

    expect(result).toMatchObject({ isError: false, text: '42' });
    expect(server.requests.at(-1)?.params).toEqual({
      name: 'execute_luau',
      arguments: { code: 'x' },
    });
    await client.closeAsync();
  });

  it('reports a tool error as isError rather than throwing', async () => {
    const { client } = await startAsync(() => toolText('boom', true));

    await expect(client.callToolAsync('execute_luau')).resolves.toMatchObject({
      isError: true,
      text: 'boom',
    });
    await client.closeAsync();
  });

  it('rejects a JSON-RPC error with its message', async () => {
    const { client } = await startAsync(() => ({
      error: { code: -32602, message: 'bad params' },
    }));

    await expect(client.requestAsync('tools/call', {})).rejects.toThrow(
      'tools/call failed: bad params'
    );
    await client.closeAsync();
  });

  it('rejects requests in flight when the server exits, with its stderr', async () => {
    const { server, client } = await startAsync(() => undefined);

    const pending = client.callToolAsync('execute_luau');
    server.exit(3, 'Studio went away');

    await expect(pending).rejects.toThrow(
      "Studio's MCP server exited (code 3): Studio went away"
    );
    await expect(client.callToolAsync('execute_luau')).rejects.toThrow(
      'exited'
    );
  });

  it('waits for the server to exit when closed', async () => {
    const { server, client } = await startAsync(() => undefined);

    await client.closeAsync();

    expect(server.child.killed).toBe(true);
    expect(client.isRunning).toBe(false);
    await expect(client.callToolAsync('execute_luau')).rejects.toThrow(
      'closed'
    );
  });

  it('closes a server that already exited without killing it again', async () => {
    const { server, client } = await startAsync(() => undefined);
    server.exit(0);
    await new Promise((resolve) => setImmediate(resolve));

    await client.closeAsync();

    expect(server.child.killed).toBe(false);
  });

  it('times out a request the server never answers', async () => {
    const { client } = await startAsync(() => undefined, 20);

    await expect(client.callToolAsync('execute_luau')).rejects.toThrow(
      'tools/call timed out after 20ms'
    );
    await client.closeAsync();
  });
});
