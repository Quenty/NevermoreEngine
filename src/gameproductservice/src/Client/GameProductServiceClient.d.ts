import { GameConfigAssetType } from '@quenty/gameconfig';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';

export interface GameProductServiceClient {
  readonly ServiceName: 'GameProductServiceClient';
  GamePassPurchased: Signal<number>;
  ProductPurchased: Signal<number>;
  AssetPurchased: Signal<number>;
  BundlePurchased: Signal<number>;
  SubscriptionPurchased: Signal<number>;
  MembershipPurchased: Signal<number>;
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  ObservePlayerAssetPurchased(
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Observable;
  ObserveAssetPurchased(
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Observable<boolean>;
  HasPlayerPurchasedThisSession(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): boolean;
  PromisePromptPurchase(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Promise<boolean>;
  PromisePlayerOwnership(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Promise<boolean>;
  ObservePlayerOwnership(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Observable<boolean>;
  PromisePlayerIsPromptOpen(player: Player): Promise<boolean>;
  PromisePlayerPromptClosed(player: Player): Promise;
  PromisePlayerOwnershipOrPrompt(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Promise<boolean>;
  PromiseGamePassOrProductUnlockOrPrompt(
    gamePassIdOrKey: number | string,
    productIdOrKey: number | string
  ): Promise<boolean>;
  Destroy(): void;
}
