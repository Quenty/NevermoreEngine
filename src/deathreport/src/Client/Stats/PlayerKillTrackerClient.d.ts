import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';

interface PlayerKillTrackerClient extends BaseObject {
  DeathsChanged: Signal;
  GetDeathValue(): IntValue;
  GetPlayer(): Player | undefined;
  GetKills(): number;
}

interface PlayerKillTrackerClientConstructor {
  readonly ClassName: 'PlayerKillTrackerClient';
  new (tracker: IntValue, serviceBag: ServiceBag): PlayerKillTrackerClient;
}

export const PlayerKillTrackerClient: PlayerKillTrackerClientConstructor;
