import { BinderProvider } from '@quenty/binder';
import { GameConfigClient } from './Config/Config/GameConfigClient';
import { GameConfigAssetClient } from './Config/Asset/GameConfigAssetClient';

export const GameConfigBindersClient: BinderProvider<{
  GameConfig: GameConfigClient;
  GameConfigAsset: GameConfigAssetClient;
}>;
