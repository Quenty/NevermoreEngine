import { GameConfigAssetType } from '@quenty/gameconfig';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';

export interface GameProductDataService {
  readonly ServiceName: 'GameProductDataService';
  GamePassPurchased: Signal<[player: Player, gamePassId: number]>;
  ProductPurchased: Signal<[player: Player, productId: number]>;
  AssetPurchased: Signal<[player: Player, assetId: number]>;
  BundlePurchased: Signal<[player: Player, bundleId: number]>;
  MembershipPurchased: Signal<[player: Player, membershipId: number]>;
  SubscriptionPurchased: Signal<[player: Player, subscriptionId: number]>;
  Init(serviceBag: ServiceBag): void;
  Start(): void;
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
  PromiseIsOwnable(
    player: Player,
    assetType: GameConfigAssetType
  ): Promise<boolean>;
  PromisePlayerIsPromptOpen(player: Player): Promise<boolean>;
  PromisePlayerPromptClosed(player: Player): Promise;
  ObservePlayerOwnership(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Observable<boolean>;
  ObservePlayerAssetPurchased(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Observable;
  ObserveAssetPurchased(
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Observable<Player>;
  PromisePlayerOwnershipOrPrompt(
    player: Player,
    assetType: GameConfigAssetType,
    idOrKey: number | string
  ): Promise<boolean>;
  Destroy(): void;
}
