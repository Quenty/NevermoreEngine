import { type BasePlaceVersionKeyword } from './deploy-config.js';

/**
 * The one thing base place resolution needs from the outside world: turning
 * "the newest published version of place X" into a version number.
 *
 * Declared as a port so this package stays free of network, auth, and rate
 * limiting. `OpenCloudClient` in the CLI satisfies it structurally, so neither
 * side imports the other.
 */
export interface PlaceVersionSource {
  resolveLatestPlaceVersionAsync(
    universeId: number,
    placeId: number,
    versionType: BasePlaceVersionKeyword
  ): Promise<number>;
}
