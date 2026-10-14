import { describe, it, expect, vi } from 'vitest';
import {
  formatAssetCreator,
  resolveAssetCreatorAsync,
  type AssetCreatorSource,
} from './asset-creator.js';

function makeSource(
  overrides: Partial<AssetCreatorSource> = {}
): AssetCreatorSource {
  return {
    getUniverseOwnerAsync: vi.fn(async () => ({ groupId: 77 })),
    getApiKeyUserIdAsync: vi.fn(async () => 4397833),
    ...overrides,
  };
}

describe('resolveAssetCreatorAsync', () => {
  it('takes an explicit owner without asking Roblox anything', async () => {
    const source = makeSource();

    expect(
      await resolveAssetCreatorAsync({ userId: 5, universeId: 1, source })
    ).toEqual({ creator: { userId: 5 }, reason: '--user-id' });
    expect(
      await resolveAssetCreatorAsync({ groupId: 6, universeId: 1, source })
    ).toEqual({ creator: { groupId: 6 }, reason: '--group-id' });

    expect(source.getUniverseOwnerAsync).not.toHaveBeenCalled();
    expect(source.getApiKeyUserIdAsync).not.toHaveBeenCalled();
  });

  it('refuses both owner flags, and an id that is not one', async () => {
    const source = makeSource();

    await expect(
      resolveAssetCreatorAsync({ userId: 5, groupId: 6, source })
    ).rejects.toThrowError(/--user-id or --group-id, not both/);
    await expect(
      resolveAssetCreatorAsync({ userId: NaN, source })
    ).rejects.toThrowError(/--user-id must be a positive integer/);
  });

  it("prefers the project universe's owner over the key's", async () => {
    // In a group's game the person holding the key is the wrong owner: the
    // experience loads assets its own creator owns.
    const source = makeSource();

    expect(await resolveAssetCreatorAsync({ universeId: 123, source })).toEqual(
      {
        creator: { groupId: 77 },
        reason: 'owns universe 123, from deploy.nevermore.json',
      }
    );
    expect(source.getApiKeyUserIdAsync).not.toHaveBeenCalled();
  });

  it("uses the API key's owner outside a project", async () => {
    const source = makeSource();

    expect(await resolveAssetCreatorAsync({ source })).toEqual({
      creator: { userId: 4397833 },
      reason: 'owns the API key',
    });
    expect(source.getUniverseOwnerAsync).not.toHaveBeenCalled();
  });

  it("falls back to the key's owner, out loud, when the universe is unreadable", async () => {
    const onFallback = vi.fn();
    const source = makeSource({
      getUniverseOwnerAsync: vi.fn(async () => {
        throw new Error('Read universe 123 failed: 403 Forbidden');
      }),
    });

    const resolved = await resolveAssetCreatorAsync({
      universeId: 123,
      source,
      onFallback,
    });

    expect(resolved.creator).toEqual({ userId: 4397833 });
    expect(onFallback).toHaveBeenCalledWith(
      expect.stringMatching(/universe 123 \(.*403 Forbidden\)/)
    );
  });

  it('says which flags to pass when no owner can be inferred', async () => {
    const source = makeSource({
      getApiKeyUserIdAsync: vi.fn(async () => {
        throw new Error('Read API key owner failed: 401 Unauthorized');
      }),
    });

    await expect(resolveAssetCreatorAsync({ source })).rejects.toThrowError(
      /401 Unauthorized[\s\S]*--user-id <id>[\s\S]*--group-id <id>/
    );
  });
});

describe('formatAssetCreator', () => {
  it('names the kind of owner', () => {
    expect(formatAssetCreator({ userId: 5 })).toBe('user 5');
    expect(formatAssetCreator({ groupId: 6 })).toBe('group 6');
  });
});
