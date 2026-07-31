import { BasePlaceResolver } from '@quenty/nevermore-deploy';
import { type OpenCloudClient } from '../open-cloud/open-cloud-client.js';

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
  args: { frozenLockfile?: boolean }
): BasePlaceResolver {
  return new BasePlaceResolver({
    source: openCloudClient,
    frozen: args.frozenLockfile ?? false,
  });
}
