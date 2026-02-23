/**
 * Unit tests for the exec command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { execHandlerAsync } from './exec.js';

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

    expect(session.execAsync).toHaveBeenCalledWith('print("test")', 5000);
  });

  it('passes undefined timeout when not specified', async () => {
    const session = createMockSession({
      success: true,
      output: [],
    });

    await execHandlerAsync(session, {
      scriptContent: 'print("test")',
    });

    expect(session.execAsync).toHaveBeenCalledWith('print("test")', undefined);
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
      execHandlerAsync(session, { scriptContent: 'print("test")' }),
    ).rejects.toThrow('Connection lost');
  });
});
