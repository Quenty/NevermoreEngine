import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';

interface PlayerDeathTrackerClient extends BaseObject {
  DeathsChanged: Signal;
  GetDeathValue(): IntValue;
  GetPlayer(): Player | undefined;
  GetKills(): number;
}

interface PlayerDeathTrackerClientConstructor {
  readonly ClassName: 'PlayerDeathTrackerClient';
  new (tracker: IntValue, serviceBag: ServiceBag): PlayerDeathTrackerClient;
}

export const PlayerDeathTrackerClient: PlayerDeathTrackerClientConstructor;
