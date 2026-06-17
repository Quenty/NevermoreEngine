import { Promise } from '@quenty/promise';

export namespace MarketplaceUtils {
  function promiseProductInfo(
    assetId: number,
    infoType: Enum.InfoType.Asset
  ): AssetProductInfo;
  function promiseProductInfo(
    assetId: number,
    infoType: Enum.InfoType.Bundle
  ): BundleInfo;
  function promiseProductInfo(
    assetId: number,
    infoType: Enum.InfoType.GamePass
  ): GamePassProductInfo;
  function promiseProductInfo(
    assetId: number,
    infoType: Enum.InfoType.Product
  ): DeveloperProductInfo;
  function promiseProductInfo(
    assetId: number,
    infoType: Enum.InfoType.Subscription
  ): SubscriptionProductInfo;
  function promiseProductInfo(
    assetId: number,
    infoType: Enum.InfoType
  ): ProductInfo;

  function promiseUserSubscriptionStatus(
    player: Player,
    subscriptionId: number
  ): Promise<UserSubscriptionStatus>;
  function promiseUserOwnsGamePass(
    userId: number,
    gamePassId: number
  ): Promise<boolean>;
  function promisePlayerOwnsAsset(
    player: Player,
    assetId: number
  ): Promise<boolean>;
  function promisePlayerOwnsBundle(
    player: Player,
    bundleId: number
  ): Promise<boolean>;
}
