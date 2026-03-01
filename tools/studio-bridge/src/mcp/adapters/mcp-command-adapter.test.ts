/**
 * Unit tests for the MCP command adapter.
 */

import { describe, it, expect, vi } from 'vitest';
import {
  buildMcpToolFromDefinition,
  buildMcpToolsFromRegistry,
} from './mcp-command-adapter.js';
import { defineCommand } from '../../commands/framework/define-command.js';
import { arg } from '../../commands/framework/arg-builder.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function mockConnection(sessionOverrides?: any) {
  const mockSession = {
    execAsync: vi.fn().mockResolvedValue({ success: true, output: [] }),
    queryStateAsync: vi.fn().mockResolvedValue({
      state: 'Edit',
      placeId: 123,
      placeName: 'Test',
      gameId: 456,
    }),
    ...sessionOverrides,
  };

  return {
    connection: {
      resolveSessionAsync: vi.fn().mockResolvedValue(mockSession),
      listSessions: vi.fn().mockReturnValue([]),
    } as any,
    mockSession,
  };
}

// ---------------------------------------------------------------------------
// buildMcpToolFromDefinition
// ---------------------------------------------------------------------------

describe('buildMcpToolFromDefinition', () => {
  it('returns undefined when mcp config is absent', () => {
    const { connection } = mockConnection();
    const cmd = defineCommand({
      group: 'console',
      name: 'exec',
      description: 'Execute code',
      category: 'execution',
      safety: 'mutate',
      scope: 'session',
      args: {},
      handler: async () => ({}),
      // no mcp field
    });

    expect(buildMcpToolFromDefinition(connection, cmd)).toBeUndefined();
  });

  describe('tool name generation', () => {
    it('generates studio_{group}_{name} for grouped commands', () => {
      const { connection } = mockConnection();
      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {},
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      expect(tool!.name).toBe('studio_console_exec');
    });

    it('generates studio_{name} for top-level commands', () => {
      const { connection } = mockConnection();
      const cmd = defineCommand({
        group: null,
        name: 'terminal',
        description: 'Start terminal',
        category: 'infrastructure',
        safety: 'none',
        scope: 'standalone',
        args: {},
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      expect(tool!.name).toBe('studio_terminal');
    });

    it('uses custom toolName override', () => {
      const { connection } = mockConnection();
      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {},
        handler: async () => ({}),
        mcp: { toolName: 'studio_run_code' },
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      expect(tool!.name).toBe('studio_run_code');
    });
  });

  describe('input schema', () => {
    it('includes command args in schema properties', () => {
      const { connection } = mockConnection();
      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {
          script: arg.positional({ description: 'Luau source code' }),
          timeout: arg.option({ description: 'Timeout ms', type: 'number' }),
        },
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const schema = tool!.inputSchema as any;

      expect(schema.properties.script).toBeDefined();
      expect(schema.properties.script.type).toBe('string');
      expect(schema.properties.timeout).toBeDefined();
      expect(schema.properties.timeout.type).toBe('number');
    });

    it('injects sessionId and context for session-scoped commands', () => {
      const { connection } = mockConnection();
      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {},
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const schema = tool!.inputSchema as any;

      expect(schema.properties.sessionId).toBeDefined();
      expect(schema.properties.context).toBeDefined();
      expect(schema.properties.context.enum).toEqual([
        'edit',
        'client',
        'server',
      ]);
    });

    it('does not inject sessionId for standalone commands', () => {
      const { connection } = mockConnection();
      const cmd = defineCommand({
        group: null,
        name: 'serve',
        description: 'Start server',
        category: 'infrastructure',
        safety: 'none',
        scope: 'standalone',
        args: {},
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const schema = tool!.inputSchema as any;

      expect(schema.properties.sessionId).toBeUndefined();
    });

    it('includes required positionals in required array', () => {
      const { connection } = mockConnection();
      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {
          script: arg.positional({ description: 'Code' }),
        },
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const schema = tool!.inputSchema as any;

      expect(schema.required).toContain('script');
    });
  });

  describe('handler — session-scoped', () => {
    it('resolves session and calls handler', async () => {
      const handler = vi.fn().mockResolvedValue({ state: 'Edit' });
      const { connection, mockSession } = mockConnection();

      const cmd = defineCommand({
        group: 'process',
        name: 'info',
        description: 'Query state',
        category: 'execution',
        safety: 'read',
        scope: 'session',
        args: {},
        handler,
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const result = await tool!.handler({
        sessionId: 'sess-1',
        context: 'edit',
      });

      expect(connection.resolveSessionAsync).toHaveBeenCalledWith(
        'sess-1',
        'edit',
      );
      expect(handler).toHaveBeenCalledWith(mockSession, {});
      expect(result.isError).toBeUndefined();
    });

    it('uses mapInput when provided', async () => {
      const handler = vi.fn().mockResolvedValue({ success: true });
      const { connection, mockSession } = mockConnection();

      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {
          script: arg.positional({ description: 'Code' }),
        },
        handler,
        mcp: {
          mapInput: (input: Record<string, unknown>) => ({
            scriptContent: input.script as string,
          }),
        },
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      await tool!.handler({ script: 'print("hi")' });

      expect(handler).toHaveBeenCalledWith(mockSession, {
        scriptContent: 'print("hi")',
      });
    });

    it('uses mapResult when provided', async () => {
      const { connection } = mockConnection();

      const cmd = defineCommand({
        group: 'viewport',
        name: 'screenshot',
        description: 'Capture screenshot',
        category: 'execution',
        safety: 'read',
        scope: 'session',
        args: {},
        handler: async () => ({ data: 'base64data', width: 100, height: 100 }),
        mcp: {
          mapResult: (result: any) => [
            { type: 'image' as const, data: result.data, mimeType: 'image/png' },
          ],
        },
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const result = await tool!.handler({});

      expect(result.content).toHaveLength(1);
      expect(result.content[0].type).toBe('image');
    });

    it('defaults to JSON text block when no mapResult', async () => {
      const { connection } = mockConnection();

      const cmd = defineCommand({
        group: 'process',
        name: 'info',
        description: 'Get info',
        category: 'execution',
        safety: 'read',
        scope: 'session',
        args: {},
        handler: async () => ({ value: 42 }),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const result = await tool!.handler({});

      expect(result.content[0].type).toBe('text');
      expect(JSON.parse((result.content[0] as any).text)).toEqual({
        value: 42,
      });
    });
  });

  describe('handler — connection-scoped', () => {
    it('passes connection directly to handler', async () => {
      const handler = vi.fn().mockResolvedValue({ sessions: [] });
      const { connection } = mockConnection();

      const cmd = defineCommand({
        group: 'process',
        name: 'list',
        description: 'List sessions',
        category: 'infrastructure',
        safety: 'read',
        scope: 'connection',
        args: {},
        handler,
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      await tool!.handler({});

      expect(handler).toHaveBeenCalledWith(connection, {});
      expect(connection.resolveSessionAsync).not.toHaveBeenCalled();
    });
  });

  describe('handler — standalone', () => {
    it('calls handler with extracted args only', async () => {
      const handler = vi.fn().mockResolvedValue({ ok: true });
      const { connection } = mockConnection();

      const cmd = defineCommand({
        group: null,
        name: 'serve',
        description: 'Start server',
        category: 'infrastructure',
        safety: 'none',
        scope: 'standalone',
        args: {
          port: arg.option({ description: 'Port', type: 'number' }),
        },
        handler,
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      await tool!.handler({ port: 9999, extra: 'ignored' });

      expect(handler).toHaveBeenCalledWith({ port: 9999 });
    });
  });

  describe('error handling', () => {
    it('wraps errors as isError response', async () => {
      const { connection } = mockConnection();
      connection.resolveSessionAsync = vi
        .fn()
        .mockRejectedValue(new Error('No sessions'));

      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {},
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const result = await tool!.handler({});

      expect(result.isError).toBe(true);
      const text = (result.content[0] as any).text;
      expect(JSON.parse(text).error).toBe('No sessions');
    });

    it('handles non-Error thrown values', async () => {
      const { connection } = mockConnection();
      connection.resolveSessionAsync = vi.fn().mockRejectedValue('bad');

      const cmd = defineCommand({
        group: 'console',
        name: 'exec',
        description: 'Execute code',
        category: 'execution',
        safety: 'mutate',
        scope: 'session',
        args: {},
        handler: async () => ({}),
        mcp: {},
      });

      const tool = buildMcpToolFromDefinition(connection, cmd);
      const result = await tool!.handler({});

      expect(result.isError).toBe(true);
      const text = (result.content[0] as any).text;
      expect(JSON.parse(text).error).toBe('bad');
    });
  });
});

// ---------------------------------------------------------------------------
// buildMcpToolsFromRegistry
// ---------------------------------------------------------------------------

describe('buildMcpToolsFromRegistry', () => {
  it('builds tools only for commands with mcp config', () => {
    const { connection } = mockConnection();

    const withMcp = defineCommand({
      group: 'console',
      name: 'exec',
      description: 'Execute code',
      category: 'execution',
      safety: 'mutate',
      scope: 'session',
      args: {},
      handler: async () => ({}),
      mcp: {},
    });

    const withoutMcp = defineCommand({
      group: null,
      name: 'serve',
      description: 'Start server',
      category: 'infrastructure',
      safety: 'none',
      scope: 'standalone',
      args: {},
      handler: async () => ({}),
    });

    const tools = buildMcpToolsFromRegistry(connection, [withMcp, withoutMcp]);

    expect(tools).toHaveLength(1);
    expect(tools[0].name).toBe('studio_console_exec');
  });

  it('returns empty array when no commands have mcp config', () => {
    const { connection } = mockConnection();

    const cmd = defineCommand({
      group: null,
      name: 'serve',
      description: 'Start server',
      category: 'infrastructure',
      safety: 'none',
      scope: 'standalone',
      args: {},
      handler: async () => ({}),
    });

    const tools = buildMcpToolsFromRegistry(connection, [cmd]);
    expect(tools).toEqual([]);
  });
});
