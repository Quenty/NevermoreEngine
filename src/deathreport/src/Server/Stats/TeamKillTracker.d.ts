import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface TeamKillTracker extends BaseObject {
  GetTeam(): Team | undefined;
  GetKills(): number;
}

interface TeamKillTrackerConstructor {
  readonly ClassName: 'TeamKillTracker';
  new (scoreObject: IntValue, serviceBag: ServiceBag): TeamKillTracker;
}

export const TeamKillTracker: TeamKillTrackerConstructor;
