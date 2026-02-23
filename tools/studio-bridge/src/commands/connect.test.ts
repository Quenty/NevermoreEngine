/**
 * Unit tests for the connect command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { connectHandlerAsync } from './connect.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockConnection(sessionInfo: {
  sessionId: string;
  context: string;
  placeName: string;
}) {
  return {
    resolveSession: vi.fn().mockResolvedValue({
      info: sessionInfo,
    }),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('connectHandlerAsync', () => {
  it('resolves session and returns metadata', async () => {
    const conn = createMockConnection({
      sessionId: 'abc-123',
      context: 'edit',
      placeName: 'TestPlace',
    });

    const result = await connectHandlerAsync(conn, { sessionId: 'abc-123' });

    expect(result.sessionId).toBe('abc-123');
    expect(result.context).toBe('edit');
    expect(result.placeName).toBe('TestPlace');
    expect(result.summary).toContain('abc-123');
    expect(result.summary).toContain('TestPlace');
    expect(result.summary).toContain('edit');
  });

  it('passes sessionId to resolveSession', async () => {
    const conn = createMockConnection({
      sessionId: 'xyz-789',
      context: 'server',
      placeName: 'GamePlace',
    });

    await connectHandlerAsync(conn, { sessionId: 'xyz-789' });

    expect(conn.resolveSession).toHaveBeenCalledWith('xyz-789');
  });

  it('propagates errors from resolveSession', async () => {
    const conn = {
      resolveSession: vi.fn().mockRejectedValue(new Error('Session not found')),
    } as any;

    await expect(
      connectHandlerAsync(conn, { sessionId: 'bad-id' }),
    ).rejects.toThrow('Session not found');
  });
});
