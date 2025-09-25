import { BaseObject } from '@quenty/baseobject';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';
import { ServiceBag } from '@quenty/servicebag';

interface DeathTrackedHumanoid extends BaseObject {}

interface DeathTrackedHumanoidConstructor {
  readonly ClassName: 'DeathTrackedHumanoid';
  new (humanoid: Humanoid, serviceBag: ServiceBag): DeathTrackedHumanoid;
}

export const DeathTrackedHumanoid: PlayerHumanoidBinder<DeathTrackedHumanoid>;
