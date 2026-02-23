/**
 * Unit tests for the run command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { runHandlerAsync } from './run.js';

// Mock fs.readFileSync
vi.mock('fs', () => ({
  readFileSync: vi.fn(),
}));

import * as fs from 'fs';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockSession(execResult: {
  success: boolean;
  output: Array<{ level: string; body: string }>;
  error?: string;
}) {
  return {
    execAsync: vi.fn().mockResolvedValue(execResult),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('runHandlerAsync', () => {
  it('reads file and delegates to session.execAsync', async () => {
    vi.mocked(fs.readFileSync).mockReturnValue('print("from file")');

    const session = createMockSession({
      success: true,
      output: [{ level: 'Print', body: 'from file' }],
    });

    const result = await runHandlerAsync(session, {
      scriptPath: '/tmp/test.lua',
    });

    expect(fs.readFileSync).toHaveBeenCalledWith('/tmp/test.lua', 'utf-8');
    expect(session.execAsync).toHaveBeenCalledWith('print("from file")', undefined);
    expect(result.success).toBe(true);
    expect(result.output).toEqual(['from file']);
    expect(result.summary).toBe('Script /tmp/test.lua executed successfully');
  });

  it('returns failure result with script path in summary', async () => {
    vi.mocked(fs.readFileSync).mockReturnValue('bad code');

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
    vi.mocked(fs.readFileSync).mockReturnValue('print("test")');

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
    vi.mocked(fs.readFileSync).mockImplementation(() => {
      throw new Error('ENOENT: no such file or directory');
    });

    const session = createMockSession({
      success: true,
      output: [],
    });

    await expect(
      runHandlerAsync(session, { scriptPath: '/tmp/missing.lua' }),
    ).rejects.toThrow('ENOENT');
  });

  it('captures multiple output lines', async () => {
    vi.mocked(fs.readFileSync).mockReturnValue('print("a") print("b")');

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
    vi.mocked(fs.readFileSync).mockReturnValue('local x = 1');

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
    vi.mocked(fs.readFileSync).mockReturnValue('print("test")');

    const session = {
      execAsync: vi.fn().mockRejectedValue(new Error('Connection lost')),
    } as any;

    await expect(
      runHandlerAsync(session, { scriptPath: '/tmp/test.lua' }),
    ).rejects.toThrow('Connection lost');
  });
});
