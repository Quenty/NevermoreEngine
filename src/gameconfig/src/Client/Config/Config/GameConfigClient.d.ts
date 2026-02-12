import { Binder } from '@quenty/binder';
import { GameConfigBase } from '@quenty/gameconfig/src/Shared/Config/Config/GameConfigBase';
import { ServiceBag } from '@quenty/servicebag';
import { GameConfigAssetClient } from '../Asset/GameConfigAssetClient';

interface GameConfigClient extends GameConfigBase {
  GetGameConfigAssetBinder(): Binder<GameConfigAssetClient>;
}

interface GameConfigClientConstructor {
  readonly ClassName: 'GameConfigClient';
  new (folder: Folder, serviceBag: ServiceBag): GameConfigClient;
}

export const GameConfigClient: GameConfigClientConstructor;
