/**
 * Unit tests for the launch command handler.
 */

import { describe, it, expect, vi } from 'vitest';

// Mock the process manager before importing the handler
vi.mock('../../../process/studio-process-manager.js', () => ({
  launchStudioAsync: vi.fn().mockResolvedValue({
    process: {},
    killAsync: vi.fn(),
  }),
}));

import { launchHandlerAsync } from './launch.js';
import { launchStudioAsync } from '../../../process/studio-process-manager.js';

describe('launchHandlerAsync', () => {
  it('calls launchStudioAsync and returns result', async () => {
    const result = await launchHandlerAsync();

    expect(launchStudioAsync).toHaveBeenCalled();
    expect(result.launched).toBe(true);
    expect(result.summary).toBe('Studio launched');
  });

  it('passes place path to launchStudioAsync', async () => {
    const result = await launchHandlerAsync({
      placePath: '/tmp/game.rbxl',
    });

    expect(launchStudioAsync).toHaveBeenCalledWith({
      placePath: '/tmp/game.rbxl',
    });
    expect(result.launched).toBe(true);
    expect(result.summary).toBe('Studio launched with /tmp/game.rbxl');
  });

  it('passes cloud place + universe ids to launchStudioAsync', async () => {
    const result = await launchHandlerAsync({
      placeId: 84760113521251,
      universeId: 9893751595,
    });

    expect(launchStudioAsync).toHaveBeenCalledWith({
      placeId: 84760113521251,
      universeId: 9893751595,
    });
    expect(result.summary).toBe(
      'Studio launched with place 84760113521251 (universe 9893751595)'
    );
  });

  it('summarizes a cloud place id without a universe id', async () => {
    const result = await launchHandlerAsync({ placeId: 123 });

    expect(result.summary).toBe('Studio launched with place 123');
  });

  it('passes an empty options object when nothing is specified', async () => {
    await launchHandlerAsync({});

    expect(launchStudioAsync).toHaveBeenCalledWith({});
  });

  it('returns correct summary without place path', async () => {
    const result = await launchHandlerAsync({});

    expect(result.summary).toBe('Studio launched');
  });

  it('propagates errors from launchStudioAsync', async () => {
    vi.mocked(launchStudioAsync).mockRejectedValueOnce(
      new Error('Studio not found')
    );

    await expect(launchHandlerAsync()).rejects.toThrow('Studio not found');
  });

  it('result shape matches LaunchResult interface', async () => {
    const result = await launchHandlerAsync();

    expect(result).toHaveProperty('launched');
    expect(result).toHaveProperty('summary');
    expect(typeof result.launched).toBe('boolean');
    expect(typeof result.summary).toBe('string');
  });
});
