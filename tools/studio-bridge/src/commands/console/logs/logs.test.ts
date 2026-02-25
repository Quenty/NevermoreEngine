/**
 * Unit tests for the logs command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { queryLogsHandlerAsync } from './logs.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockSession(logsResult: {
  entries: Array<{ level: string; body: string; timestamp: number }>;
  total: number;
  bufferCapacity: number;
}) {
  return {
    queryLogsAsync: vi.fn().mockResolvedValue(logsResult),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('queryLogsHandlerAsync', () => {
  it('returns log entries with summary', async () => {
    const session = createMockSession({
      entries: [
        { level: 'Print', body: 'Hello world', timestamp: 1000 },
        { level: 'Warning', body: 'Watch out', timestamp: 2000 },
      ],
      total: 42,
      bufferCapacity: 1000,
    });

    const result = await queryLogsHandlerAsync(session);

    expect(result.entries).toHaveLength(2);
    expect(result.total).toBe(42);
    expect(result.bufferCapacity).toBe(1000);
    expect(result.summary).toBe('2 entries (42 total in buffer)');
  });

  it('passes default options to session', async () => {
    const session = createMockSession({
      entries: [],
      total: 0,
      bufferCapacity: 1000,
    });

    await queryLogsHandlerAsync(session);

    expect(session.queryLogsAsync).toHaveBeenCalledWith({
      count: 50,
      direction: 'tail',
      levels: undefined,
      includeInternal: undefined,
    });
  });

  it('passes custom options to session', async () => {
    const session = createMockSession({
      entries: [],
      total: 0,
      bufferCapacity: 500,
    });

    await queryLogsHandlerAsync(session, {
      count: 100,
      direction: 'head',
      levels: ['Error', 'Warning'],
      includeInternal: true,
    });

    expect(session.queryLogsAsync).toHaveBeenCalledWith({
      count: 100,
      direction: 'head',
      levels: ['Error', 'Warning'],
      includeInternal: true,
    });
  });

  it('handles empty entries', async () => {
    const session = createMockSession({
      entries: [],
      total: 0,
      bufferCapacity: 1000,
    });

    const result = await queryLogsHandlerAsync(session);

    expect(result.entries).toEqual([]);
    expect(result.total).toBe(0);
    expect(result.summary).toBe('0 entries (0 total in buffer)');
  });

  it('handles entries with all log levels', async () => {
    const entries = [
      { level: 'Print', body: 'info message', timestamp: 1000 },
      { level: 'Info', body: 'info message', timestamp: 2000 },
      { level: 'Warning', body: 'warning message', timestamp: 3000 },
      { level: 'Error', body: 'error message', timestamp: 4000 },
    ];
    const session = createMockSession({
      entries,
      total: 4,
      bufferCapacity: 1000,
    });

    const result = await queryLogsHandlerAsync(session);

    expect(result.entries).toHaveLength(4);
    expect(result.entries[0].level).toBe('Print');
    expect(result.entries[1].level).toBe('Info');
    expect(result.entries[2].level).toBe('Warning');
    expect(result.entries[3].level).toBe('Error');
  });

  it('propagates errors from session', async () => {
    const session = {
      queryLogsAsync: vi.fn().mockRejectedValue(new Error('Connection lost')),
    } as any;

    await expect(queryLogsHandlerAsync(session)).rejects.toThrow('Connection lost');
  });

  it('handles missing fields gracefully', async () => {
    const session = {
      queryLogsAsync: vi.fn().mockResolvedValue({
        entries: undefined,
        total: undefined,
        bufferCapacity: undefined,
      }),
    } as any;

    const result = await queryLogsHandlerAsync(session);

    expect(result.entries).toEqual([]);
    expect(result.total).toBe(0);
    expect(result.bufferCapacity).toBe(0);
    expect(result.summary).toBe('0 entries (0 total in buffer)');
  });
});
