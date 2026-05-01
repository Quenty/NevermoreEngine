/**
 * Unit tests for per-command CLI formatters.
 * Tests the formatResult callbacks in isolation with mock data.
 */

import { describe, it, expect } from 'vitest';
import { execCommand } from './console/exec/exec.js';
import { logsCommand, formatLogsText } from './console/logs/logs.js';
import { listCommand, formatSessionsTable } from './process/list/list.js';
import { infoCommand, formatStateText } from './process/info/info.js';
import { queryCommand, formatQueryText } from './explorer/query/query.js';
import { screenshotCommand } from './viewport/screenshot/screenshot.js';

describe('exec formatter', () => {
  const format = execCommand.cli!.format!;

  it('joins output lines', () => {
    const result = { success: true, output: ['Hello', 'World'], summary: 'ok' };
    expect(format(result)).toBe('Hello\nWorld');
  });

  it('appends error when present', () => {
    const result = {
      success: false,
      output: ['partial'],
      error: 'boom',
      summary: 'fail',
    };
    expect(format(result)).toBe('partial\nboom');
  });

  it('falls back to summary when no output lines', () => {
    const result = {
      success: true,
      output: [],
      summary: 'Script executed successfully',
    };
    expect(format(result)).toBe('Script executed successfully');
  });

  it('handles error with no output', () => {
    const result = {
      success: false,
      output: [],
      error: 'boom',
      summary: 'fail',
    };
    expect(format(result)).toBe('boom');
  });
});

describe('logs formatter', () => {
  it('returns summary when no entries', () => {
    const result = {
      entries: [],
      total: 0,
      bufferCapacity: 100,
      summary: '0 entries',
    };
    expect(formatLogsText(result)).toBe('0 entries');
  });

  it('formats timestamped log lines', () => {
    const result = {
      entries: [
        { level: 'Print' as const, body: 'Hello', timestamp: 1000000 },
        { level: 'Error' as const, body: 'Boom', timestamp: 1001000 },
      ],
      total: 2,
      bufferCapacity: 100,
      summary: '2 entries',
    };

    const text = formatLogsText(result);
    expect(text).toContain('Hello');
    expect(text).toContain('Boom');
    expect(text).toContain('(2 of 2 entries)');
  });

  it('is wired into command definition', () => {
    expect(logsCommand.cli!.format).toBe(formatLogsText);
  });
});

describe('list formatter', () => {
  it('returns summary when no sessions', () => {
    const result = { sessions: [], summary: 'No active sessions.' };
    expect(formatSessionsTable(result)).toBe('No active sessions.');
  });

  it('formats session table', () => {
    const result = {
      sessions: [
        {
          sessionId: 'abcdefgh-1234',
          placeName: 'TestPlace',
          state: 'Edit' as const,
          context: 'edit' as const,
          pluginVersion: '1.0.0',
          capabilities: [],
          connectedAt: new Date(),
          origin: 'user' as const,
          instanceId: 'inst-1',
          placeId: 123,
          gameId: 456,
        },
      ],
      summary: '1 session(s) connected.',
    };

    const text = formatSessionsTable(result);
    expect(text).toContain('Session');
    expect(text).toContain('abcdefg'); // truncated session ID
    expect(text).toContain('TestPlace');
    expect(text).toContain('Edit');
  });

  it('is wired into command definition', () => {
    expect(listCommand.cli!.format).toBe(formatSessionsTable);
  });
});

describe('info formatter', () => {
  it('formats key-value pairs', () => {
    const result = {
      state: 'Edit' as const,
      placeName: 'MyPlace',
      placeId: 123,
      gameId: 456,
      summary: 'Mode: Edit, Place: MyPlace (123)',
    };

    const text = formatStateText(result);
    expect(text).toContain('Mode:');
    expect(text).toContain('MyPlace');
    expect(text).toContain('123');
    expect(text).toContain('456');
  });

  it('is wired into command definition', () => {
    expect(infoCommand.cli!.format).toBe(formatStateText);
  });
});

describe('query formatter', () => {
  it('formats a simple node', () => {
    const result = {
      node: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
      },
      summary: 'Workspace (Workspace) at game.Workspace',
    };

    const text = formatQueryText(result);
    expect(text).toContain('Workspace');
  });

  it('formats nested children with indentation', () => {
    const result = {
      node: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        children: [
          {
            name: 'Part',
            className: 'Part',
            path: 'game.Workspace.Part',
          },
        ],
      },
      summary: 'Workspace',
    };

    const text = formatQueryText(result);
    const lines = text.split('\n');
    // Root should not be indented
    expect(lines[0]).toMatch(/^Workspace/);
    // Child should be indented
    expect(lines[1]).toMatch(/^ {2}Part/);
  });

  it('formats properties and attributes', () => {
    const result = {
      node: {
        name: 'Part',
        className: 'Part',
        path: 'game.Workspace.Part',
        properties: { Size: [4, 1, 2] },
        attributes: { Health: 100 },
      },
      summary: 'Part',
    };

    const text = formatQueryText(result);
    expect(text).toContain('Size:');
    expect(text).toContain('@Health:');
  });

  it('is wired into command definition', () => {
    expect(queryCommand.cli!.format).toBe(formatQueryText);
  });
});

describe('screenshot formatter', () => {
  it('format returns summary only', () => {
    const format = screenshotCommand.cli!.format!;
    const result = {
      data: 'base64...',
      width: 800,
      height: 600,
      summary: 'Screenshot captured (800x600)',
    };
    expect(format(result)).toBe('Screenshot captured (800x600)');
  });

  it('json override omits data field', () => {
    const json = screenshotCommand.cli!.json!;
    const result = {
      data: 'base64...',
      width: 800,
      height: 600,
      summary: 'Screenshot captured (800x600)',
    };
    const parsed = JSON.parse(json(result));
    expect(parsed).not.toHaveProperty('data');
    expect(parsed.width).toBe(800);
    expect(parsed.height).toBe(600);
    expect(parsed.summary).toBe('Screenshot captured (800x600)');
  });

  it('has binaryField set to data', () => {
    expect(screenshotCommand.cli!.binaryField).toBe('data');
  });
});
