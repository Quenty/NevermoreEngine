import { BinderProvider } from '@quenty/binder';
import { GameConfig } from './Config/Config/GameConfig';
import { GameConfigAsset } from './Config/Asset/GameConfigAsset';

export const GameConfigBindersServer: BinderProvider<{
  GameConfig: GameConfig;
  GameConfigAsset: GameConfigAsset;
}>;
