import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface PlayerKillTracker extends BaseObject {
  GetKillValue(): IntValue;
  GetPlayer(): Player | undefined;
  GetKills(): number;
}

interface PlayerKillTrackerConstructor {
  readonly ClassName: 'PlayerKillTracker';
  new (scoreObject: IntValue, serviceBag: ServiceBag): PlayerKillTracker;
}

export const PlayerKillTracker: PlayerKillTrackerConstructor;
