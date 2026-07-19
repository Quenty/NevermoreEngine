import { GameConfigAssetBase } from '@quenty/gameconfig/src/Shared/Config/Asset/GameConfigAssetBase';
import { ServiceBag } from '@quenty/servicebag';

interface GameConfigAssetClient extends GameConfigAssetBase {}

interface GameConfigAssetClientConstructor {
  readonly ClassName: 'GameConfigAssetClient';
  new (folder: Folder, serviceBag: ServiceBag): GameConfigAssetClient;
}

export const GameConfigAssetClient: GameConfigAssetClientConstructor;
