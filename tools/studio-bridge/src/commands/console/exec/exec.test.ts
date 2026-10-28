/**
 * Unit tests for the unified exec command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import {
  execCommand,
  execHandlerAsync,
  runHandlerAsync,
  type ExecResult,
} from './exec.js';

// Mock fs/promises.readFile for runHandlerAsync
vi.mock('fs/promises', () => ({
  readFile: vi.fn(),
}));

import * as fs from 'fs/promises';

function createMockSession(execResult: {
  success: boolean;
  output: Array<{ level: string; body: string }>;
  error?: string;
}) {
  return {
    execAsync: vi.fn().mockResolvedValue(execResult),
  } as any;
}

describe('execHandlerAsync', () => {
  it('returns success result with summary', async () => {
    const session = createMockSession({
      success: true,
      output: [{ level: 'Print', body: 'Hello world' }],
    });

    const result = await execHandlerAsync(session, {
      scriptContent: 'print("Hello world")',
    });

    expect(result.success).toBe(true);
    expect(result.output).toEqual(['Hello world']);
    expect(result.error).toBeUndefined();
    expect(result.summary).toBe('Script executed successfully');
  });

  it('returns failure result with error', async () => {
    const session = createMockSession({
      success: false,
      output: [],
      error: 'Syntax error on line 1',
    });

    const result = await execHandlerAsync(session, {
      scriptContent: 'bad code',
    });

    expect(result.success).toBe(false);
    expect(result.output).toEqual([]);
    expect(result.error).toBe('Syntax error on line 1');
    expect(result.summary).toBe('Script failed: Syntax error on line 1');
  });

  it('forwards timeout to session.execAsync', async () => {
    const session = createMockSession({
      success: true,
      output: [],
    });

    await execHandlerAsync(session, {
      scriptContent: 'print("test")',
      timeout: 5000,
    });

    expect(session.execAsync).toHaveBeenCalledWith(
      'print("test")',
      5000,
      undefined
    );
  });

  it('forwards script args to session.execAsync', async () => {
    const session = createMockSession({
      success: true,
      output: [],
    });

    await execHandlerAsync(session, {
      scriptContent: 'return ...',
      args: ['Player1', '3'],
    });

    expect(session.execAsync).toHaveBeenCalledWith('return ...', undefined, [
      'Player1',
      '3',
    ]);
  });

  it('passes undefined timeout when not specified', async () => {
    const session = createMockSession({
      success: true,
      output: [],
    });

    await execHandlerAsync(session, {
      scriptContent: 'print("test")',
    });

    expect(session.execAsync).toHaveBeenCalledWith(
      'print("test")',
      undefined,
      undefined
    );
  });

  it('captures multiple output lines', async () => {
    const session = createMockSession({
      success: true,
      output: [
        { level: 'Print', body: 'line 1' },
        { level: 'Print', body: 'line 2' },
        { level: 'Warning', body: 'warning line' },
      ],
    });

    const result = await execHandlerAsync(session, {
      scriptContent: 'print("line 1") print("line 2") warn("warning line")',
    });

    expect(result.output).toEqual(['line 1', 'line 2', 'warning line']);
  });

  it('handles empty output array', async () => {
    const session = createMockSession({
      success: true,
      output: [],
    });

    const result = await execHandlerAsync(session, {
      scriptContent: 'local x = 1',
    });

    expect(result.output).toEqual([]);
  });

  it('handles missing output field gracefully', async () => {
    const session = {
      execAsync: vi.fn().mockResolvedValue({
        success: true,
        output: undefined,
      }),
    } as any;

    const result = await execHandlerAsync(session, {
      scriptContent: 'local x = 1',
    });

    expect(result.output).toEqual([]);
  });

  it('propagates errors from session', async () => {
    const session = {
      execAsync: vi.fn().mockRejectedValue(new Error('Connection lost')),
    } as any;

    await expect(
      execHandlerAsync(session, { scriptContent: 'print("test")' })
    ).rejects.toThrow('Connection lost');
  });

  it('carries the return values through', async () => {
    const session = {
      execAsync: vi.fn().mockResolvedValue({
        success: true,
        output: [],
        returnValues: [12345, { type: 'Nil' }],
      }),
    } as any;

    const result = await execHandlerAsync(session, {
      scriptContent: 'return game.PlaceId, nil',
    });

    expect(result.returnValues).toEqual([12345, { type: 'Nil' }]);
  });
});

describe('execCommand text format', () => {
  const format = execCommand.cli!.format!;

  function formatResult(result: Partial<ExecResult>): string {
    return format({
      success: true,
      output: [],
      summary: 'Script executed successfully',
      ...result,
    });
  }

  it('prints a returned string raw so returned JSON stays parseable', () => {
    expect(formatResult({ returnValues: ['{"ok":true}'] })).toBe('{"ok":true}');
  });

  it('prints output lines before the return values', () => {
    expect(formatResult({ output: ['hello'], returnValues: [42, true] })).toBe(
      'hello\n42\ttrue'
    );
  });

  it('spells a returned nil and JSON-encodes tables and datatypes', () => {
    expect(
      formatResult({
        returnValues: [
          { type: 'Nil' },
          [1, 2],
          { type: 'Vector3', value: [1, 2, 3] },
        ],
      })
    ).toBe('nil\t[1,2]\t{"type":"Vector3","value":[1,2,3]}');
  });

  it('falls back to the summary when nothing was printed or returned', () => {
    expect(formatResult({ returnValues: [] })).toBe(
      'Script executed successfully'
    );
  });

  it('appends the error after any output', () => {
    expect(
      formatResult({ success: false, output: ['before'], error: 'boom' })
    ).toBe('before\nboom');
  });
});

describe('runHandlerAsync', () => {
  it('reads file and delegates to session.execAsync', async () => {
    vi.mocked(fs.readFile).mockResolvedValue('print("from file")');

    const session = createMockSession({
      success: true,
      output: [{ level: 'Print', body: 'from file' }],
    });

    const result = await runHandlerAsync(session, {
      scriptPath: '/tmp/test.lua',
    });

    expect(fs.readFile).toHaveBeenCalledWith('/tmp/test.lua', 'utf-8');
    expect(session.execAsync).toHaveBeenCalledWith(
      'print("from file")',
      undefined
    );
    expect(result.success).toBe(true);
    expect(result.output).toEqual(['from file']);
    expect(result.summary).toBe('Script /tmp/test.lua executed successfully');
  });

  it('returns failure result with script path in summary', async () => {
    vi.mocked(fs.readFile).mockResolvedValue('bad code');

    const session = createMockSession({
      success: false,
      output: [],
      error: 'Syntax error',
    });

    const result = await runHandlerAsync(session, {
      scriptPath: '/tmp/broken.lua',
    });

    expect(result.success).toBe(false);
    expect(result.error).toBe('Syntax error');
    expect(result.summary).toBe('Script /tmp/broken.lua failed: Syntax error');
  });

  it('forwards timeout to session.execAsync', async () => {
    vi.mocked(fs.readFile).mockResolvedValue('print("test")');

    const session = createMockSession({
      success: true,
      output: [],
    });

    await runHandlerAsync(session, {
      scriptPath: '/tmp/test.lua',
      timeout: 10_000,
    });

    expect(session.execAsync).toHaveBeenCalledWith('print("test")', 10_000);
  });

  it('throws when file cannot be read', async () => {
    vi.mocked(fs.readFile).mockRejectedValue(
      new Error('ENOENT: no such file or directory')
    );

    const session = createMockSession({
      success: true,
      output: [],
    });

    await expect(
      runHandlerAsync(session, { scriptPath: '/tmp/missing.lua' })
    ).rejects.toThrow('ENOENT');
  });

  it('captures multiple output lines', async () => {
    vi.mocked(fs.readFile).mockResolvedValue('print("a") print("b")');

    const session = createMockSession({
      success: true,
      output: [
        { level: 'Print', body: 'a' },
        { level: 'Print', body: 'b' },
      ],
    });

    const result = await runHandlerAsync(session, {
      scriptPath: '/tmp/multi.lua',
    });

    expect(result.output).toEqual(['a', 'b']);
  });

  it('handles empty output', async () => {
    vi.mocked(fs.readFile).mockResolvedValue('local x = 1');

    const session = createMockSession({
      success: true,
      output: [],
    });

    const result = await runHandlerAsync(session, {
      scriptPath: '/tmp/silent.lua',
    });

    expect(result.output).toEqual([]);
  });

  it('propagates errors from session', async () => {
    vi.mocked(fs.readFile).mockResolvedValue('print("test")');

    const session = {
      execAsync: vi.fn().mockRejectedValue(new Error('Connection lost')),
    } as any;

    await expect(
      runHandlerAsync(session, { scriptPath: '/tmp/test.lua' })
    ).rejects.toThrow('Connection lost');
  });
});
