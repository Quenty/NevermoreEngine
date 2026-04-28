import { GameConfigAssetBase } from '../../../Shared/Config/Asset/GameConfigAssetBase';
import { ServiceBag } from '@quenty/servicebag';

interface GameConfigAsset extends GameConfigAssetBase {}

interface GameConfigAssetConstructor {
  readonly ClassName: 'GameConfigAsset';
  new (obj: Folder, serviceBag: ServiceBag): GameConfigAsset;
}

export const GameConfigAsset: GameConfigAssetConstructor;
