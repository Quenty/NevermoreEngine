import { ServiceBag } from '@quenty/servicebag';
import { GameConfigAssetType } from '../Shared/Config/AssetTypes/GameConfigAssetTypes';
import { GameConfigPicker } from '../Shared/Config/Picker/GameConfigPicker';

export interface GameConfigService {
  readonly ServiceName: 'GameConfigService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  AddBadge(assetKey: string, badgeId: number): void;
  AddProduct(assetKey: string, productId: number): void;
  AddPass(assetKey: string, passId: number): void;
  AddPlace(assetKey: string, placeId: number): void;
  AddAsset(assetKey: string, assetId: number): void;
  AddSubscription(assetKey: string, subscriptionId: number): void;
  AddBundle(assetKey: string, bundleId: number): void;
  AddTypedAsset(
    assetType: GameConfigAssetType,
    assetKey: string,
    assetId: number
  ): Folder;
  GetConfigPicker(): GameConfigPicker;
  GetPreferredParent(): Instance;
  Destroy(): void;
}
