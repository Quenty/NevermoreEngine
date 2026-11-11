import { type AssetCreator } from '../open-cloud/open-cloud-client.js';

/** The two lookups an owner can be inferred from; `OpenCloudClient` is one. */
export interface AssetCreatorSource {
  getUniverseOwnerAsync(universeId: number): Promise<AssetCreator>;
  getApiKeyUserIdAsync(): Promise<number>;
}

export interface ResolveAssetCreatorOptions {
  userId?: number;
  groupId?: number;
  /** The universe of the nearest deploy.nevermore.json, when there is one. */
  universeId?: number;
  source: AssetCreatorSource;
  /** Told when an inference had to be skipped, so the fallback is not silent. */
  onFallback?: (message: string) => void;
}

export interface ResolvedAssetCreator {
  creator: AssetCreator;
  /** Why this owner, for the line that tells the user who it will be. */
  reason: string;
}

export function formatAssetCreator(creator: AssetCreator): string {
  return 'userId' in creator
    ? `user ${creator.userId}`
    : `group ${creator.groupId}`;
}

/**
 * Decide who owns newly uploaded assets, so a bare
 * `nevermore deploy asset upload icon.png` works.
 *
 * An explicit flag wins. Otherwise the owner of the surrounding project's
 * universe is preferred over the API key's owner: an experience can only be
 * relied on to load assets its own creator owns, so in a group's game the
 * person holding the key is the wrong owner.
 */
export async function resolveAssetCreatorAsync(
  options: ResolveAssetCreatorOptions
): Promise<ResolvedAssetCreator> {
  const { userId, groupId, universeId, source } = options;

  if (userId != null && groupId != null) {
    throw new Error('Pass --user-id or --group-id, not both.');
  }
  for (const [flag, id] of [
    ['--user-id', userId],
    ['--group-id', groupId],
  ] as const) {
    if (id != null && (!Number.isSafeInteger(id) || id < 1)) {
      throw new Error(`${flag} must be a positive integer.`);
    }
  }

  if (userId != null) {
    return { creator: { userId }, reason: '--user-id' };
  }
  if (groupId != null) {
    return { creator: { groupId }, reason: '--group-id' };
  }

  if (universeId != null) {
    try {
      return {
        creator: await source.getUniverseOwnerAsync(universeId),
        reason: `owns universe ${universeId}, from deploy.nevermore.json`,
      };
    } catch (err) {
      options.onFallback?.(
        `Could not read who owns universe ${universeId} ` +
          `(${err instanceof Error ? err.message : String(err)}); ` +
          `uploading as the API key's owner instead.`
      );
    }
  }

  try {
    return {
      creator: { userId: await source.getApiKeyUserIdAsync() },
      reason: 'owns the API key',
    };
  } catch (err) {
    throw new Error(
      [
        `Could not work out who should own the new assets: ${
          err instanceof Error ? err.message : String(err)
        }`,
        'Check the key with "nevermore login --status", or name the owner:',
        '  --user-id <id>    the Roblox user who should own them',
        '  --group-id <id>   the Roblox group who should own them',
      ].join('\n')
    );
  }
}
