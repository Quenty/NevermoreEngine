/**
 * Unit tests for the MCP server tool registration.
 *
 * Tool names now follow the `studio_{group}_{name}` convention from
 * the declarative command system.
 */

import { describe, it, expect, vi } from 'vitest';
import { buildToolDefinitions } from './mcp-server.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockConnection() {
  return {
    listSessions: vi.fn().mockReturnValue([]),
    resolveSessionAsync: vi.fn().mockResolvedValue({
      info: { sessionId: 'test-session' },
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
  it('registers the expected number of tools', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);

    // 8 commands with mcp config: exec, logs, query, screenshot, info, list, close, action
    expect(tools).toHaveLength(8);
  });

  it('registers tools with correct group-based names', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const names = tools.map((t) => t.name);

    expect(names).toContain('studio_console_exec');
    expect(names).toContain('studio_console_logs');
    expect(names).toContain('studio_explorer_query');
    expect(names).toContain('studio_viewport_screenshot');
    expect(names).toContain('studio_process_info');
    expect(names).toContain('studio_process_list');
    expect(names).toContain('studio_process_close');
    expect(names).toContain('studio_action');
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

  it('studio_process_list schema has sessionId and context (connection-scoped)', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const listTool = tools.find((t) => t.name === 'studio_process_list')!;

    const props = listTool.inputSchema.properties as Record<string, any>;
    expect(props.sessionId).toBeDefined();
    expect(props.context).toBeDefined();
  });

  it('studio_explorer_query schema has path property', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const queryTool = tools.find((t) => t.name === 'studio_explorer_query')!;

    const props = queryTool.inputSchema.properties as Record<string, any>;
    expect(props.path).toBeDefined();
  });

  it('session-based tools have sessionId and context in schema', () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);

    const sessionTools = [
      'studio_console_exec',
      'studio_console_logs',
      'studio_explorer_query',
      'studio_viewport_screenshot',
      'studio_process_info',
      'studio_process_close',
      'studio_action',
    ];

    for (const name of sessionTools) {
      const tool = tools.find((t) => t.name === name)!;
      expect(tool).toBeDefined();
      const props = tool.inputSchema.properties as Record<string, any>;
      expect(props.sessionId).toBeDefined();
      expect(props.context).toBeDefined();
      expect(props.context.enum).toEqual(['edit', 'client', 'server']);
    }
  });

  it('studio_process_list handler calls listSessionsHandlerAsync', async () => {
    const connection = createMockConnection();
    connection.listSessions.mockReturnValue([
      { sessionId: 's1', placeName: 'Place1' },
    ]);

    const tools = buildToolDefinitions(connection);
    const listTool = tools.find((t) => t.name === 'studio_process_list')!;

    const result = await listTool.handler({});

    expect(result.isError).toBeUndefined();
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('text');

    const text = (result.content[0] as { type: 'text'; text: string }).text;
    const parsed = JSON.parse(text);
    expect(parsed.sessions).toBeDefined();
  });

  it('studio_process_info handler resolves session and queries state', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const infoTool = tools.find((t) => t.name === 'studio_process_info')!;

    const result = await infoTool.handler({ context: 'edit' });

    expect(connection.resolveSessionAsync).toHaveBeenCalledWith(undefined, 'edit');
    expect(result.isError).toBeUndefined();

    const text = (result.content[0] as { type: 'text'; text: string }).text;
    const parsed = JSON.parse(text);
    expect(parsed.state).toBe('Edit');
    expect(parsed.placeId).toBe(123);
  });

  it('studio_viewport_screenshot handler returns image content block', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const screenshotTool = tools.find((t) => t.name === 'studio_viewport_screenshot')!;

    const result = await screenshotTool.handler({});

    expect(result.isError).toBeUndefined();
    expect(result.content).toHaveLength(1);
    expect(result.content[0].type).toBe('image');

    const block = result.content[0] as { type: 'image'; data: string; mimeType: string };
    expect(block.data).toBe('base64data');
    expect(block.mimeType).toBe('image/png');
  });

  it('studio_console_exec handler passes script content', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const execTool = tools.find((t) => t.name === 'studio_console_exec')!;

    const result = await execTool.handler({ code: 'print("hello")' });

    expect(connection.resolveSessionAsync).toHaveBeenCalled();
    expect(result.isError).toBeUndefined();

    const text = (result.content[0] as { type: 'text'; text: string }).text;
    const parsed = JSON.parse(text);
    expect(parsed.success).toBe(true);
    expect(parsed.output).toContain('hello');
  });

  it('studio_console_logs handler passes options correctly', async () => {
    const connection = createMockConnection();
    const tools = buildToolDefinitions(connection);
    const logsTool = tools.find((t) => t.name === 'studio_console_logs')!;

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
    connection.resolveSessionAsync.mockRejectedValue(new Error('No sessions connected'));

    const tools = buildToolDefinitions(connection);
    const infoTool = tools.find((t) => t.name === 'studio_process_info')!;

    const result = await infoTool.handler({});

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
