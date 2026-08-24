import { Binder } from '@quenty/binder';
import { GameConfigAssetBase } from './GameConfigAssetBase';
import { GameConfigAssetType } from '../AssetTypes/GameConfigAssetTypes';
import { ServiceBag } from '@quenty/servicebag';
import { Promise } from '@quenty/promise';

type GameConfigAssetTypeToProductInfo = {
  badge: BadgeInfo;
  product: DeveloperProductInfo;
  pass: GamePassProductInfo;
  asset: AssetProductInfo;
  bundle: BundleInfo;
};

export namespace GameConfigAssetUtils {
  function create(
    binder: Binder<GameConfigAssetBase>,
    assetType: GameConfigAssetType,
    assetKey: string,
    assetId: number
  ): Folder;
  function promiseCloudDataForAssetType<T extends GameConfigAssetType>(
    serviceBag: ServiceBag,
    assetType: T,
    assetId: number
  ): Promise<
    T extends keyof GameConfigAssetTypeToProductInfo
      ? GameConfigAssetTypeToProductInfo[T]
      : ProductInfo
  >;
}
