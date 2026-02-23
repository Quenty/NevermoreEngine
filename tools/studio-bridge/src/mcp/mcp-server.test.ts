/**
 * Unit tests for the MCP server tool registration.
 */

import { describe, it, expect, vi } from 'vitest';
import { buildToolDefinitions } from './mcp-server.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockConnection() {
  return {
    listSessions: vi.fn().mockReturnValue([]),
    resolveSession: vi.fn().mockResolvedValue({
      queryStateAsync: vi.fn().mockResolvedValue({
        state: 'Edit',
        placeId: 123,
        placeName: 'Test',
        gameId: 456,
      }),
      captureScreenshotAsync: vi.fn().mockResolvedValue({
        data: 'base64data',
        format: 'png',
        width: 1920,
        height: 1080,
      }),
      queryLogsAsync: vi.fn().mockResolvedValue({
        entries: [],
        total: 0,
        bufferCapacity: 500,
      }),
      queryDataModelAsync: vi.fn().mockResolvedValue({
        instance: {
          name: 'Workspace',
          className: 'Workspace',
          path: 'game.Workspace',
          children: [],
        },
      }),
      execAsync: vi.fn().mockResolvedValue({
        success: true,
        output: [{ level: 'Print', body: 'hello' }],
      }),
    }),
    disconnectAsync: vi.fn(),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('buildToolDefinitions', () => {
  it('registers exactly 6 tools', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);

    expect(tools).toHaveLength(6);
  });

  it('registers tools with correct names', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const names = tools.map((t) => t.name);

    expect(names).toContain('studio_sessions');
    expect(names).toContain('studio_state');
    expect(names).toContain('studio_screenshot');
    expect(names).toContain('studio_logs');
    expect(names).toContain('studio_query');
    expect(names).toContain('studio_exec');
  });

  it('all tools have descriptions', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);

    for (const tool of tools) {
      expect(tool.description).toBeTruthy();
      expect(typeof tool.description).toBe('string');
    }
  });

  it('all tools have input schemas with type "object"', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);

    for (const tool of tools) {
      expect(tool.inputSchema).toBeDefined();
      expect(tool.inputSchema.type).toBe('object');
    }
  });

  it('studio_sessions schema has no required properties', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const sessionsTool = tools.find((t) => t.name === 'studio_sessions')!;

    expect(sessionsTool.inputSchema.required).toBeUndefined();
  });

  it('studio_exec schema requires "script" property', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const execTool = tools.find((t) => t.name === 'studio_exec')!;

    expect(execTool.inputSchema.required).toContain('script');
  });

  it('studio_query schema requires "path" property', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const queryTool = tools.find((t) => t.name === 'studio_query')!;

    expect(queryTool.inputSchema.required).toContain('path');
  });

  it('session-based tools have sessionId and context in schema', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);

    const sessionTools = ['studio_state', 'studio_screenshot', 'studio_logs', 'studio_query', 'studio_exec'];

    for (const name of sessionTools) {
      const tool = tools.find((t) => t.name === name)!;
      const props = tool.inputSchema.properties as Record<string, any>;
      expect(props.sessionId).toBeDefined();
      expect(props.context).toBeDefined();
      expect(props.context.enum).toEqual(['edit', 'client', 'server']);
    }
  });

  it('studio_sessions handler calls listSessionsHandlerAsync', async () => {
    const connection = createMockConnection();
    connection.listSessions.mockReturnValue([
      { sessionId: 's1', placeName: 'Place1' },
    ]);

    const tools = buildToolDefinitions(connection);
    const sessionsTool = tools.find((t) => t.name === 'studio_sessions')!;

    const result = await sessionsTool.handler({});

    expect(result.isError).toBeUndefined();
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('text');

    const text = (result.content[0] as { type: 'text'; text: string }).text;
    const parsed = JSON.parse(text);
    expect(parsed.sessions).toBeDefined();
    expect(parsed.summary).toBeDefined();
  });

  it('studio_state handler resolves session and queries state', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const stateTool = tools.find((t) => t.name === 'studio_state')!;

    const result = await stateTool.handler({ context: 'edit' });

    expect(connection.resolveSession).toHaveBeenCalledWith(undefined, 'edit');
    expect(result.isError).toBeUndefined();

    const text = (result.content[0] as { type: 'text'; text: string }).text;
    const parsed = JSON.parse(text);
    expect(parsed.state).toBe('Edit');
    expect(parsed.placeId).toBe(123);
  });

  it('studio_screenshot handler returns image content block', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const screenshotTool = tools.find((t) => t.name === 'studio_screenshot')!;

    const result = await screenshotTool.handler({});

    expect(result.isError).toBeUndefined();
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('image');

    const block = result.content[0] as { type: 'image'; data: string; mimeType: string };
    expect(block.data).toBe('base64data');
    expect(block.mimeType).toBe('image/png');
  });

  it('studio_exec handler passes script content', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const execTool = tools.find((t) => t.name === 'studio_exec')!;

    const result = await execTool.handler({ script: 'print("hello")' });

    expect(connection.resolveSession).toHaveBeenCalled();
    expect(result.isError).toBeUndefined();

    const text = (result.content[0] as { type: 'text'; text: string }).text;
    const parsed = JSON.parse(text);
    expect(parsed.success).toBe(true);
    expect(parsed.output).toContain('hello');
  });

  it('studio_logs handler passes options correctly', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const logsTool = tools.find((t) => t.name === 'studio_logs')!;

    const result = await logsTool.handler({
      count: 10,
      direction: 'head',
      levels: ['Warning', 'Error'],
      includeInternal: true,
    });

    expect(result.isError).toBeUndefined();
    const text = (result.content[0] as { type: 'text'; text: string }).text;
    const parsed = JSON.parse(text);
    expect(parsed.entries).toBeDefined();
    expect(parsed.total).toBeDefined();
    expect(parsed.bufferCapacity).toBeDefined();
  });

  it('tool handler returns isError when session resolution fails', async () => {
    const connection = createMockConnection();
    connection.resolveSession.mockRejectedValue(new Error('No sessions connected'));

    const tools = buildToolDefinitions(connection);
    const stateTool = tools.find((t) => t.name === 'studio_state')!;

    const result = await stateTool.handler({});

    expect(result.isError).toBe(true);
    const text = (result.content[0] as { type: 'text'; text: string }).text;
    expect(JSON.parse(text).error).toBe('No sessions connected');
  });

  it('unique tool names (no duplicates)', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const names = tools.map((t) => t.name);
    const unique = new Set(names);

    expect(unique.size).toBe(names.length);
  });
});
