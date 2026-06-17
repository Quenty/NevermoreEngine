import { BaseObject } from '@quenty/baseobject';
import { GameConfigAssetType } from '../AssetTypes/GameConfigAssetTypes';
import { GameConfigAssetBase } from '../Asset/GameConfigAssetBase';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

interface GameConfigBase extends BaseObject {
  GetFolder(): Folder;
  GetAssetsOfType(assetType: GameConfigAssetType): GameConfigAssetBase[];
  GetAssetsOfTypeAndKey(
    assetType: GameConfigAssetType,
    assetKey: string
  ): GameConfigAssetBase[];
  GetAssetsOfTypeAndId(
    assetType: GameConfigAssetType,
    assetId: number
  ): GameConfigAssetBase[];
  ObserveAssetByTypeAndKeyBrio(
    assetType: GameConfigAssetType,
    assetKey: string
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveAssetByTypeAndIdBrio(
    assetType: GameConfigAssetType,
    assetId: number
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveAssetByIdBrio(assetId: number): Observable<Brio<GameConfigAssetBase>>;
  ObserveAssetByKeyBrio(
    assetKey: string
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveAssetByTypeBrio(
    assetType: GameConfigAssetType
  ): Observable<Brio<GameConfigAssetBase>>;
  InitObservation(): void;
  ObserveGameId(): Observable<number>;
  GetGameId(): number;
  GetConfigName(): string;
  ObserveConfigName(): Observable<string>;
}

interface GameConfigBaseConstructor {
  readonly ClassName: 'GameConfigBase';
  new (folder: Folder): GameConfigBase;
}

export const GameConfigBase: GameConfigBaseConstructor;
