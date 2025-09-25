import { GameConfigAssetType } from './GameConfigAssetTypes';

export namespace GameConfigAssetTypeUtils {
  function isAssetType(value: unknown): value is GameConfigAssetType;
  function getPlural(assetType: GameConfigAssetType): string;
}
