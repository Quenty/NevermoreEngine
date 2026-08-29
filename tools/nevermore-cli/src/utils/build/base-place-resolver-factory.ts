import { BasePlaceResolver } from '@quenty/nevermore-deploy';
import { type OpenCloudClient } from '../open-cloud/open-cloud-client.js';

/**
 * A resolver that can only answer from the lock file.
 *
 * Watch registration reads baselines with `peekAsync`, which never leaves disk,
 * so registering needs no Open Cloud credentials. A dryrun has no client to
 * build a real resolver from and must not acquire one just to register — and if
 * some future caller does ask this to resolve, throwing beats quietly reaching
 * the network on a dryrun.
 */
export function createLockOnlyBasePlaceResolver(): BasePlaceResolver {
  return new BasePlaceResolver({
    source: {
      resolveLatestPlaceVersionAsync: async () => {
        throw new Error(
          'This resolver answers from deploy.nevermore.lock.json only and ' +
            'cannot reach Open Cloud.'
        );
      },
    },
  });
}

/**
 * Build the one resolver a run shares.
 *
 * Every command that can merge a base place goes through here, so `deploy run`,
 * `batch deploy`, `test`, and `batch test` cannot end up disagreeing about lock
 * policy. `OpenCloudClient` satisfies the resolver's `PlaceVersionSource` port
 * structurally — the deploy-config package never learns about Open Cloud.
 */
export function createBasePlaceResolver(
  openCloudClient: OpenCloudClient,
  args: { frozenLockfile?: boolean; refreshBasePlace?: boolean }
): BasePlaceResolver {
  if (args.frozenLockfile && args.refreshBasePlace) {
    throw new Error(
      '--frozen-lockfile and --refresh-base-place contradict each other: ' +
        'one forbids resolving base places, the other forces it.'
    );
  }
  return new BasePlaceResolver({
    source: openCloudClient,
    frozen: args.frozenLockfile ?? false,
    refresh: args.refreshBasePlace ?? false,
  });
}
