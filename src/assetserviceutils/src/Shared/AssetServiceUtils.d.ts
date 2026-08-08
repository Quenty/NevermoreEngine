import { Promise } from '@quenty/promise';

export namespace AssetServiceUtils {
  function promiseAssetIdsForPackage(
    packageAssetId: number
  ): Promise<ReturnType<AssetService['GetAssetIdsForPackage']>>;
  function promiseGamePlaces(): Promise<
    ReturnType<AssetService['GetGamePlacesAsync']>
  >;
  function promiseBundleDetails(
    bundleId: number
  ): Promise<ReturnType<AssetService['GetBundleDetailsAsync']>>;
}
