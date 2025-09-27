import { ServiceBag } from '@quenty/servicebag';

export interface MarketplaceServiceCache {
  readonly ServiceName: 'MarketplaceServiceCache';
  Init(serviceBag: ServiceBag): void;
  PromiseProductInfo(
    productId: number,
    infoType: Enum.InfoType.Asset
  ): AssetProductInfo;
  PromiseProductInfo(
    productId: number,
    infoType: Enum.InfoType.Bundle
  ): BundleInfo;
  PromiseProductInfo(
    productId: number,
    infoType: Enum.InfoType.GamePass
  ): GamePassProductInfo;
  PromiseProductInfo(
    productId: number,
    infoType: Enum.InfoType.Product
  ): DeveloperProductInfo;
  PromiseProductInfo(
    productId: number,
    infoType: Enum.InfoType.Subscription
  ): SubscriptionProductInfo;
  PromiseProductInfo(productId: number, infoType: Enum.InfoType): ProductInfo;
}
