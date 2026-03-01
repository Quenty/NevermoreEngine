/**
 * Unit tests for the MCP adapter.
 */

import { describe, it, expect, vi } from 'vitest';
import { createMcpTool } from './mcp-adapter.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockConnection(sessions: any[] = []) {
  return {
    listSessions: () => sessions,
    resolveSessionAsync: vi.fn().mockResolvedValue({ id: 'test-session' }),
    disconnectAsync: vi.fn(),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('createMcpTool', () => {
  it('generates tool with correct name, description, and schema', () => {
    const connection = createMockConnection();
    const handler = vi.fn().mockResolvedValue({ data: 'test' });

    const tool = createMcpTool(connection, {
      name: 'my_tool',
      description: 'A test tool',
      inputSchema: {
        type: 'object',
        properties: { foo: { type: 'string' } },
      },
      needsSession: false,
      handler,
    });

    expect(tool.name).toBe('my_tool');
    expect(tool.description).toBe('A test tool');
    expect(tool.inputSchema).toEqual({
      type: 'object',
      properties: { foo: { type: 'string' } },
    });
  });

  it('calls connection-based handler when needsSession is false', async () => {
    const connection = createMockConnection();
    const handler = vi.fn().mockResolvedValue({ sessions: [] });

    const tool = createMcpTool(connection, {
      name: 'studio_sessions',
      description: 'List sessions',
      inputSchema: { type: 'object', properties: {} },
      needsSession: false,
      handler,
    });

    const result = await tool.handler({});

    expect(handler).toHaveBeenCalledWith(connection);
    expect(result.isError).toBeUndefined();
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('text');
  });

  it('resolves session and calls handler when needsSession is true', async () => {
    const mockSession = { id: 'sess-1' };
    const connection = createMockConnection();
    connection.resolveSessionAsync.mockResolvedValue(mockSession);

    const handler = vi.fn().mockResolvedValue({ state: 'Edit' });

    const tool = createMcpTool(connection, {
      name: 'studio_state',
      description: 'Query state',
      inputSchema: { type: 'object', properties: {} },
      needsSession: true,
      handler,
    });

    const result = await tool.handler({ sessionId: 'sess-1', context: 'edit' });

    expect(connection.resolveSessionAsync).toHaveBeenCalledWith('sess-1', 'edit');
    expect(handler).toHaveBeenCalledWith(mockSession);
    expect(result.isError).toBeUndefined();
  });

  it('passes mapped input to session handler', async () => {
    const mockSession = { id: 'sess-1' };
    const connection = createMockConnection();
    connection.resolveSessionAsync.mockResolvedValue(mockSession);

    const handler = vi.fn().mockResolvedValue({
      success: true,
      output: ['hello'],
    });

    const tool = createMcpTool(connection, {
      name: 'studio_exec',
      description: 'Execute script',
      inputSchema: {
        type: 'object',
        properties: {
          script: { type: 'string' },
        },
        required: ['script'],
      },
      needsSession: true,
      mapInput: (input) => ({ scriptContent: input.script as string }),
      handler,
    });

    await tool.handler({ script: 'print("hi")' });

    expect(handler).toHaveBeenCalledWith(mockSession, {
      scriptContent: 'print("hi")',
    });
  });

  it('wraps errors as isError: true responses', async () => {
    const connection = createMockConnection();
    connection.resolveSessionAsync.mockRejectedValue(new Error('Session not found'));

    const handler = vi.fn();

    const tool = createMcpTool(connection, {
      name: 'studio_state',
      description: 'Query state',
      inputSchema: { type: 'object', properties: {} },
      needsSession: true,
      handler,
    });

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('text');
    const text = (result.content[0] as { type: 'text'; text: string }).text;
    expect(JSON.parse(text)).toEqual({ error: 'Session not found' });
  });

  it('wraps handler errors as isError: true responses', async () => {
    const mockSession = { id: 'sess-1' };
    const connection = createMockConnection();
    connection.resolveSessionAsync.mockResolvedValue(mockSession);

    const handler = vi.fn().mockRejectedValue(new Error('Connection lost'));

    const tool = createMcpTool(connection, {
      name: 'studio_exec',
      description: 'Execute',
      inputSchema: { type: 'object', properties: {} },
      needsSession: true,
      handler,
    });

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    const text = (result.content[0] as { type: 'text'; text: string }).text;
    expect(JSON.parse(text).error).toBe('Connection lost');
  });

  it('uses custom mapResult for content blocks', async () => {
    const connection = createMockConnection();
    const handler = vi.fn().mockResolvedValue({
      data: 'iVBORw0KGgo=',
      width: 100,
      height: 100,
    });

    const tool = createMcpTool(connection, {
      name: 'studio_screenshot',
      description: 'Take screenshot',
      inputSchema: { type: 'object', properties: {} },
      needsSession: false,
      handler,
      mapResult: (result: any) => [{
        type: 'image' as const,
        data: result.data,
        mimeType: 'image/png',
      }],
    });

    const result = await tool.handler({});

    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('image');
    const block = result.content[0] as { type: 'image'; data: string; mimeType: string };
    expect(block.data).toBe('iVBORw0KGgo=');
    expect(block.mimeType).toBe('image/png');
  });

  it('defaults to JSON.stringify when no mapResult is provided', async () => {
    const connection = createMockConnection();
    const handler = vi.fn().mockResolvedValue({ foo: 'bar', count: 42 });

    const tool = createMcpTool(connection, {
      name: 'test_tool',
      description: 'Test',
      inputSchema: { type: 'object', properties: {} },
      needsSession: false,
      handler,
    });

    const result = await tool.handler({});

    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('text');
    const text = (result.content[0] as { type: 'text'; text: string }).text;
    expect(JSON.parse(text)).toEqual({ foo: 'bar', count: 42 });
  });

  it('handles non-Error thrown values', async () => {
    const connection = createMockConnection();
    const handler = vi.fn().mockRejectedValue('string error');

    const tool = createMcpTool(connection, {
      name: 'test_tool',
      description: 'Test',
      inputSchema: { type: 'object', properties: {} },
      needsSession: false,
      handler,
    });

    const result = await tool.handler({});

    expect(result.isError).toBe(true);
    const text = (result.content[0] as { type: 'text'; text: string }).text;
    expect(JSON.parse(text).error).toBe('string error');
  });

  it('passes undefined sessionId and context when not provided', async () => {
    const mockSession = { id: 'auto' };
    const connection = createMockConnection();
    connection.resolveSessionAsync.mockResolvedValue(mockSession);

    const handler = vi.fn().mockResolvedValue({});

    const tool = createMcpTool(connection, {
      name: 'studio_state',
      description: 'Query state',
      inputSchema: { type: 'object', properties: {} },
      needsSession: true,
      handler,
    });

    await tool.handler({});

    expect(connection.resolveSessionAsync).toHaveBeenCalledWith(undefined, undefined);
  });
});
