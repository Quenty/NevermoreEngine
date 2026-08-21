import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { PlayerKillTracker } from './PlayerKillTracker';

interface PlayerKillTrackerAssigner extends BaseObject {
  GetPlayerKills(player: Player): number | undefined;
  GetPlayerKillTracker(player: Player): PlayerKillTracker | undefined;
}

interface PlayerKillTrackerAssignerConstructor {
  readonly ClassName: 'PlayerKillTrackerAssigner';
  new (serviceBag: ServiceBag): PlayerKillTrackerAssigner;
}

export const PlayerKillTrackerAssigner: PlayerKillTrackerAssignerConstructor;
