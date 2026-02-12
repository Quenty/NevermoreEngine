import { BaseObject } from '@quenty/baseobject';
import { GameConfigAssetType } from '@quenty/gameconfig';
import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { PlayerAssetMarketTracker } from './PlayerAssetMarketTracker';
import { PlayerAssetOwnershipTracker } from '../Ownership/PlayerAssetOwnershipTracker';

interface PlayerProductManagerBase extends BaseObject {
  ExportMarketTrackers(parent: Instance): void;
  GetPlayer(): Player;
  IsOwnable(assetType: GameConfigAssetType): boolean;
  IsPromptOpen(): boolean;
  PromisePlayerPromptClosed(): Promise;
  GetAssetTrackerOrError(
    assetType: GameConfigAssetType
  ): PlayerAssetMarketTracker;
  GetOwnershipTrackerOrError(
    assetType: GameConfigAssetType
  ): PlayerAssetOwnershipTracker;
}

interface PlayerProductManagerBaseConstructor {
  readonly ClassName: 'PlayerProductManagerBase';
  new (player: Player, serviceBag: ServiceBag): PlayerProductManagerBase;
}

export const PlayerProductManagerBase: PlayerProductManagerBaseConstructor;
