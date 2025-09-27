import { ServiceBag } from '@quenty/servicebag';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';
import { BaseObject } from '@quenty/baseobject';

interface Motor6DStackHumanoid extends BaseObject {}

interface Motor6DStackHumanoidConstructor {
  readonly ClassName: 'Motor6DStackHumanoid';
  new (humanoid: Humanoid, serviceBag: ServiceBag): Motor6DStackHumanoid;
}

export const Motor6DStackHumanoid: PlayerHumanoidBinder<Motor6DStackHumanoid>;
