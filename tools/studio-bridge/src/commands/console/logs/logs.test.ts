/**
 * Unit tests for the logs command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { formatLogsText, parseSince, queryLogsHandlerAsync } from './logs.js';

function createMockSession(logsResult: {
  entries: Array<{ level: string; body: string; timestamp: number }>;
  total: number;
  bufferCapacity: number;
}) {
  return {
    queryLogsAsync: vi.fn().mockResolvedValue(logsResult),
  } as any;
}

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
    expect(result.summary).toBe('2 entries (42 in buffer)');
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
      since: undefined,
      groupRepeats: true,
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
      since: 1793125630,
    });

    expect(session.queryLogsAsync).toHaveBeenCalledWith({
      count: 100,
      direction: 'head',
      levels: ['Error', 'Warning'],
      includeInternal: true,
      since: 1793125630,
      groupRepeats: true,
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
    expect(result.summary).toBe('0 entries (0 in buffer)');
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

    await expect(queryLogsHandlerAsync(session)).rejects.toThrow(
      'Connection lost'
    );
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
    expect(result.summary).toBe('0 entries (0 in buffer)');
  });
});

describe('parseSince', () => {
  const now = Date.parse('2026-10-27T18:00:00Z');

  it('reads a duration back from now', () => {
    expect(parseSince('30s', now)).toBe(now / 1000 - 30);
    expect(parseSince('5m', now)).toBe(now / 1000 - 300);
    expect(parseSince('2h', now)).toBe(now / 1000 - 7200);
  });

  it('reads a date', () => {
    expect(parseSince('2026-10-27T17:00:00Z', now)).toBe(now / 1000 - 3600);
  });

  it('refuses anything else', () => {
    expect(() => parseSince('yesterday', now)).toThrow(/Can't read --since/);
  });
});

describe('repeat grouping', () => {
  it('is asked of the plugin unless turned off', async () => {
    const session = createMockSession({
      entries: [],
      total: 0,
      bufferCapacity: 1000,
    });

    await queryLogsHandlerAsync(session);
    await queryLogsHandlerAsync(session, { groupRepeats: false });

    expect(session.queryLogsAsync.mock.calls[0][0].groupRepeats).toBe(true);
    expect(session.queryLogsAsync.mock.calls[1][0].groupRepeats).toBe(false);
  });

  it('counts each repeat in the summary', async () => {
    const session = createMockSession({
      entries: [
        { level: 'Print', body: 'tick', timestamp: 1, repeats: 3 },
        { level: 'Print', body: 'done', timestamp: 4 },
      ],
      total: 4,
      bufferCapacity: 1000,
    } as any);

    expect((await queryLogsHandlerAsync(session)).summary).toBe(
      '4 entries (4 in buffer)'
    );
  });
});

describe('formatLogsText', () => {
  it('shows the repeat count and counts every repeat as shown', () => {
    const text = formatLogsText({
      entries: [
        { level: 'Print', body: 'tick', timestamp: 1793125630, repeats: 3 },
      ],
      total: 3,
      bufferCapacity: 1000,
      summary: '3 entries (3 in buffer)',
    });

    expect(text).toContain('tick');
    expect(text).toContain('(x3)');
    expect(text).toContain('(3 shown, 3 in buffer)');
    expect(text).toContain(new Date(1793125630 * 1000).toLocaleTimeString());
  });
});
