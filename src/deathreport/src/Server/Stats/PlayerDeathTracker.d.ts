import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface PlayerDeathTracker extends BaseObject {}

interface PlayerDeathTrackerConstructor {
  readonly ClassName: 'PlayerDeathTracker';
  new (scoreObject: IntValue, serviceBag: ServiceBag): PlayerDeathTracker;
}

export const PlayerDeathTracker: PlayerDeathTrackerConstructor;
