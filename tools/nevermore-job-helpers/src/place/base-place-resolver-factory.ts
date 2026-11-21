import {
  BasePlaceResolver,
  resolveBasePlaceLockMode,
  type BasePlaceLockFlags,
  type BasePlaceLockMode,
  type PlaceVersionSource,
} from '@quenty/nevermore-deploy';

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
 * Every command that can merge a base place goes through here — `deploy run`,
 * `batch deploy`, `test`, `batch test`, and `studio-bridge process launch` — so
 * they cannot end up disagreeing about lock policy. Each command states its
 * default lock mode; the `--frozen-lockfile` and `--refresh-base-place` flags
 * override it the same way everywhere.
 */
export function createBasePlaceResolver(
  source: PlaceVersionSource,
  flags: BasePlaceLockFlags,
  defaultMode: BasePlaceLockMode = 'write'
): BasePlaceResolver {
  return new BasePlaceResolver({
    source,
    lockMode: resolveBasePlaceLockMode(flags, defaultMode),
  });
}
