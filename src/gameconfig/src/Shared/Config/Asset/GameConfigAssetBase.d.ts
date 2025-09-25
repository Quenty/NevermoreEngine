import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { GameConfigAssetType } from '../AssetTypes/GameConfigAssetTypes';
import { CancelToken } from '@quenty/canceltoken';
import { Promise } from '@quenty/promise';

export interface GameConfigAssetState {
  assetId: number;
  assetKey: string;
  assetType: GameConfigAssetType;
}

interface GameConfigAssetBase extends BaseObject {
  ObserveTranslatedName(): Observable<string>;
  ObserveTranslatedDescription(): Observable<string>;
  SetNameTranslationKey(nameTranslationKey: string | undefined): void;
  SetDescriptionTranslationKey(
    descriptionTranslationKey: string | undefined
  ): void;
  GetAssetId(): number;
  ObserveAssetId(): Observable<number>;
  GetAssetType(): GameConfigAssetType | undefined;
  ObserveAssetType(): Observable<GameConfigAssetType | undefined>;
  ObserveAssetKey(): Observable<string>;
  GetAssetKey(): string;
  ObserveState(): Observable<GameConfigAssetState>;
  PromiseCloudPriceInRobux(
    cancelToken?: CancelToken
  ): Promise<number | undefined>;
  PromiseCloudName(cancelToken?: CancelToken): Promise<string | undefined>;
  PromiseColor(): Promise<Color3>;
  PromiseNameTranslationKey(
    cancelToken?: CancelToken
  ): Promise<string | undefined>;
  ObserveNameTranslationKey(): Observable<string | undefined>;
  ObserveDescriptionTranslationKey(): Observable<string | undefined>;
  ObserveCloudName(): Observable<string | undefined>;
  ObserveCloudDescription(): Observable<string | undefined>;
  ObserveCloudPriceInRobux(): Observable<number | undefined>;
  ObserveCloudIconImageAssetId(): Observable<number | undefined>;
}

interface GameConfigAssetBaseConstructor {
  readonly ClassName: 'GameConfigAssetBase';
  new (obj: Folder, serviceBag: ServiceBag): GameConfigAssetBase;
}

export const GameConfigAssetBase: GameConfigAssetBaseConstructor;
