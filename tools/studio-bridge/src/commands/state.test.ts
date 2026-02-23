/**
 * Unit tests for the state command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { queryStateHandlerAsync } from './state.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockSession(stateResult: {
  state: string;
  placeId: number;
  placeName: string;
  gameId: number;
}) {
  return {
    queryStateAsync: vi.fn().mockResolvedValue(stateResult),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('queryStateHandlerAsync', () => {
  it('returns state result with summary', async () => {
    const session = createMockSession({
      state: 'Edit',
      placeId: 12345,
      placeName: 'TestPlace',
      gameId: 67890,
    });

    const result = await queryStateHandlerAsync(session);

    expect(result.state).toBe('Edit');
    expect(result.placeId).toBe(12345);
    expect(result.placeName).toBe('TestPlace');
    expect(result.gameId).toBe(67890);
    expect(result.summary).toContain('Edit');
    expect(result.summary).toContain('TestPlace');
    expect(result.summary).toContain('12345');
  });

  it('calls session.queryStateAsync', async () => {
    const session = createMockSession({
      state: 'Play',
      placeId: 100,
      placeName: 'GamePlace',
      gameId: 200,
    });

    await queryStateHandlerAsync(session);

    expect(session.queryStateAsync).toHaveBeenCalledOnce();
  });

  it('handles different state values correctly', async () => {
    for (const state of ['Edit', 'Play', 'Paused', 'Run', 'Server', 'Client']) {
      const session = createMockSession({
        state,
        placeId: 1,
        placeName: 'Place',
        gameId: 2,
      });

      const result = await queryStateHandlerAsync(session);
      expect(result.state).toBe(state);
      expect(result.summary).toContain(state);
    }
  });

  it('propagates errors from session', async () => {
    const session = {
      queryStateAsync: vi.fn().mockRejectedValue(new Error('Connection lost')),
    } as any;

    await expect(queryStateHandlerAsync(session)).rejects.toThrow('Connection lost');
  });
});
