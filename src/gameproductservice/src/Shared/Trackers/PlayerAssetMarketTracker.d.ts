import { BaseObject } from '@quenty/baseobject';
import { Brio } from '@quenty/brio';
import { GameConfigAssetType } from '@quenty/gameconfig';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { PlayerAssetOwnershipTracker } from '../Ownership/PlayerAssetOwnershipTracker';
import { Promise } from '@quenty/promise';

interface PlayerAssetMarketTracker extends BaseObject {
  Purchased: Signal<number>;
  PromptClosed: Signal<[id: number, isPurchased: boolean]>;
  ShowPromptRequested: Signal<number>;
  ObservePromptOpenCount(): Observable<number>;
  ObserveAssetPurchased(idOrKey: number | string): Observable;
  GetOwnershipTracker(): PlayerAssetOwnershipTracker | undefined;
  PromisePromptPurchase(idOrKey: number | string): Promise<boolean>;
  SetOwnershipTracker(
    ownershipTracker: PlayerAssetOwnershipTracker | undefined
  ): void;
  GetAssetType(): GameConfigAssetType;
  HasPurchasedThisSession(idOrKey: number | string): boolean;
  IsPromptOpen(): boolean;
  HandlePurchaseEvent(id: number, isPurchased: boolean): void;
  HandlePromptClosedEvent(id: number): void;
}

interface PlayerAssetMarketTrackerConstructor {
  readonly ClassName: 'PlayerAssetMarketTracker';
  new (
    assetType: GameConfigAssetType,
    convertIds: (idOrKey: number | string) => number | undefined,
    observeIdsBrio: (idOrKey: number | string) => Observable<Brio<number>>
  ): PlayerAssetMarketTracker;
}

export const PlayerAssetMarketTracker: PlayerAssetMarketTrackerConstructor;
