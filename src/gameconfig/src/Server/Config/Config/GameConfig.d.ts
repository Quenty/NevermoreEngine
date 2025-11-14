import { Binder } from '@quenty/binder';
import { GameConfigBase } from '../../../Shared/Config/Config/GameConfigBase';
import { ServiceBag } from '@quenty/servicebag';
import { GameConfigAsset } from '../Asset/GameConfigAsset';

interface GameConfig extends GameConfigBase {
  GetGameConfigAssetBinder(): Binder<GameConfigAsset>;
}

interface GameConfigConstructor {
  readonly ClassName: 'GameConfig';
  new (obj: Instance, serviceBag: ServiceBag): GameConfig;
}

export const GameConfig: GameConfigConstructor;
