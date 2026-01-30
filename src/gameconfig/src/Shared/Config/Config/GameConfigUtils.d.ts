import { Binder } from '@quenty/binder';
import { GameConfigBase } from './GameConfigBase';
import { GameConfigAssetType } from '../AssetTypes/GameConfigAssetTypes';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

export namespace GameConfigUtils {
  function create(binder: Binder<GameConfigBase>, gameId: number): Folder;
  function getOrCreateAssetFolder(
    config: Folder,
    assetType: GameConfigAssetType
  ): Folder;
  function observeAssetFolderBrio(
    config: Folder,
    assetType: GameConfigAssetType
  ): Observable<Brio<Folder>>;
}
