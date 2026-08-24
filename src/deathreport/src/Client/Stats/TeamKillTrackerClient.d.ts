import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';

interface TeamKillTrackerClient extends BaseObject {
  DeathsChanged: Signal;
  GetDeathValue(): IntValue;
  GetTeam(): Team | undefined;
  GetKills(): number;
}

interface TeamKillTrackerClientConstructor {
  readonly ClassName: 'TeamKillTrackerClient';
  new (tracker: IntValue, serviceBag: ServiceBag): TeamKillTrackerClient;
}

export const TeamKillTrackerClient: TeamKillTrackerClientConstructor;
