import { CmdrLike } from '@quenty/cmdrservice';
import { GameConfigPicker } from '../Config/Picker/GameConfigPicker';
import { GameConfigAssetType } from '../Config/AssetTypes/GameConfigAssetTypes';

export namespace GameConfigCmdrUtils {
  function registerAssetTypes(
    cmdr: CmdrLike,
    configPicker: GameConfigPicker
  ): void;
  function registerAssetType(
    cmdr: CmdrLike,
    configPicker: GameConfigPicker,
    assetType: GameConfigAssetType
  ): void;
}
