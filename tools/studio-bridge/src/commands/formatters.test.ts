/**
 * Unit tests for per-command CLI formatters.
 * Tests the formatResult callbacks in isolation with mock data.
 */

import { describe, it, expect } from 'vitest';
import { stripVTControlCharacters } from 'node:util';
import { execCommand } from './console/exec/exec.js';
import { logsCommand, formatLogsText } from './console/logs/logs.js';
import { listCommand, formatSessionsTable } from './process/list/list.js';
import { infoCommand, formatStateText } from './process/info/info.js';
import {
  inspectCommand,
  formatInspectText,
} from './explorer/inspect/inspect.js';
import { screenshotCommand } from './viewport/screenshot/screenshot.js';

describe('exec formatter', () => {
  const format = execCommand.cli!.body!;

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

  it('renders nothing, leaving the summary to the adapter, when no output lines', () => {
    const result = {
      success: true,
      output: [],
      summary: 'Script executed successfully',
    };
    expect(format(result)).toBe('');
  });

  it('is data, so its summary goes to stderr', () => {
    expect(execCommand.cli!.output).toBe('data');
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
  it('renders nothing when no entries', () => {
    const result = {
      entries: [],
      total: 0,
      bufferCapacity: 100,
      summary: '0 entries',
    };
    expect(formatLogsText(result)).toBe('');
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
    expect(text).not.toContain('2 entries');
  });

  it('is wired into command definition', () => {
    expect(logsCommand.cli!.body).toBe(formatLogsText);
  });
});

describe('list formatter', () => {
  it('renders nothing when no sessions', () => {
    const result = { sessions: [], summary: 'No active sessions.' };
    expect(formatSessionsTable(result)).toBe('');
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
    expect(listCommand.cli!.body).toBe(formatSessionsTable);
  });
});

describe('info formatter', () => {
  it('formats key-value pairs', () => {
    const result = {
      sessionId: 'my-place-1a2b-edit',
      instanceId: 'my-place-1a2b',
      context: 'edit' as const,
      origin: 'user' as const,
      state: 'Edit' as const,
      placeName: 'MyPlace',
      placeId: 123,
      gameId: 456,
      plugin: { version: 'abc', expectedVersion: 'abc', upToDate: true },
      connectedAt: new Date().toISOString(),
      summary: 'Mode: Edit, Place: MyPlace (123)',
    };

    const text = formatStateText(result);
    expect(text).toContain('Mode:');
    expect(text).toContain('MyPlace');
    expect(text).toContain('123');
    expect(text).toContain('456');
  });

  it('is wired into command definition', () => {
    expect(infoCommand.cli!.body).toBe(formatStateText);
  });
});

describe('inspect formatter', () => {
  const leaf = { properties: [], attributes: [], childCount: 0 };

  it('formats nested children with indentation', () => {
    const text = formatInspectText({
      instance: {
        ...leaf,
        name: 'Workspace',
        className: 'Workspace',
        path: 'Workspace',
        childCount: 1,
        children: [
          { ...leaf, name: 'Part', className: 'Part', path: 'Workspace.Part' },
        ],
      },
      summary: 'Workspace and 1 child',
    });

    const lines = text.split('\n');
    expect(lines[0]).toMatch(/^Workspace/);
    expect(lines[1]).toMatch(/^ {2}Part/);
  });

  it('formats properties and attributes', () => {
    const text = formatInspectText({
      instance: {
        ...leaf,
        name: 'Door',
        className: 'Part',
        path: 'Workspace.Door',
        properties: [
          { name: 'Size', text: '4, 1, 2', value: { X: 4, Y: 1, Z: 2 } },
          {
            name: 'Source',
            text: 'local a\nreturn a',
            value: 'local a\nreturn a',
          },
        ],
        attributes: [{ name: 'Health', text: '100', value: 100 }],
      },
      summary: 'Door, no children',
    });

    expect(stripVTControlCharacters(text).split('\n')).toEqual([
      'Door (Part)',
      '  Size: 4, 1, 2',
      '  Source: local a\\nreturn a',
      '  @Health: 100',
    ]);
  });

  it('lists the place top level as its services, without game', () => {
    const text = formatInspectText({
      instance: {
        ...leaf,
        name: 'Place1',
        className: 'DataModel',
        path: 'Place1',
        childCount: 2,
        children: [
          {
            ...leaf,
            name: 'Workspace',
            className: 'Workspace',
            path: 'Workspace',
          },
          {
            ...leaf,
            name: 'Lighting',
            className: 'Lighting',
            path: 'Lighting',
          },
        ],
      },
      summary: '2 services',
    });

    expect(stripVTControlCharacters(text).split('\n')).toEqual([
      'Workspace',
      'Lighting',
    ]);
  });

  it('is wired into command definition', () => {
    expect(inspectCommand.cli!.body).toBe(formatInspectText);
  });
});

describe('screenshot formatter', () => {
  it('has no body, so its text is the summary alone', () => {
    expect(screenshotCommand.cli!.body).toBeUndefined();
  });

  it('json override omits data field', () => {
    const json = screenshotCommand.cli!.json!;
    const result = {
      data: 'base64...',
      width: 800,
      height: 600,
      source: 'captureService' as const,
      summary: 'Screenshot captured (800x600)',
    };
    const parsed = JSON.parse(json(result));
    expect(parsed).not.toHaveProperty('data');
    expect(parsed.width).toBe(800);
    expect(parsed.height).toBe(600);
    expect(parsed.source).toBe('captureService');
    expect(parsed.summary).toBe('Screenshot captured (800x600)');
  });

  it('has binaryField set to data', () => {
    expect(screenshotCommand.cli!.binaryField).toBe('data');
  });
});
