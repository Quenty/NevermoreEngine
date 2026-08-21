import { BaseObject } from '@quenty/baseobject';
import { Binder } from '@quenty/binder';
import { ServiceBag } from '@quenty/servicebag';
import { GameConfigAssetType } from '../AssetTypes/GameConfigAssetTypes';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';
import { GameConfigAssetBase } from '../Asset/GameConfigAssetBase';
import { Promise } from '@quenty/promise';
import { GameConfigBase } from '../Config/GameConfigBase';

interface GameConfigPicker extends BaseObject {
  ObserveActiveAssetOfTypeBrio(
    assetType: GameConfigAssetType
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveActiveAssetOfAssetTypeAndKeyBrio(
    assetType: GameConfigAssetType,
    assetKey: string
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveActiveAssetOfAssetTypeAndIdBrio(
    assetType: GameConfigAssetType,
    assetId: number
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveActiveAssetOfAssetIdBrio(
    assetId: number
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveActiveAssetOfKeyBrio(
    assetKey: string
  ): Observable<Brio<GameConfigAssetBase>>;
  ObserveActiveConfigsBrio(): Observable<Brio<GameConfigAssetBase>>;
  GetActiveConfigs(): GameConfigAssetBase[];
  FindFirstActiveAssetOfId(
    assetType: GameConfigAssetType,
    assetId: number
  ): GameConfigAssetBase | undefined;
  PromisePriceInRobux(
    assetType: GameConfigAssetType,
    assetIdOrKey: number | string
  ): Promise<number | undefined>;
  FindFirstActiveAssetOfKey(
    assetType: GameConfigAssetType,
    assetKey: string
  ): GameConfigAssetBase | undefined;
  GetAllActiveAssetsOfType(
    assetType: GameConfigAssetType
  ): GameConfigAssetBase[];
  ToAssetId(
    assetType: GameConfigAssetType,
    assetIdOrKey: number | string
  ): number | undefined;
  ObserveToAssetIdBrio(
    assetType: GameConfigAssetType,
    assetIdOrKey: number | string
  ): Observable<Brio<number>>;
}

interface GameConfigPickerConstructor {
  readonly ClassName: 'GameConfigPicker';
  new (
    serviceBag: ServiceBag,
    gameConfigBinder: Binder<GameConfigBase>,
    gameConfigAssetBinder: Binder<GameConfigAssetBase>
  ): GameConfigPicker;
}

export const GameConfigPicker: GameConfigPickerConstructor;
