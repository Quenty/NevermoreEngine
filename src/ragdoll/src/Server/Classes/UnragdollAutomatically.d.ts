import { ServiceBag } from '@quenty/servicebag';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';
import { BaseObject } from '@quenty/baseobject';

interface UnragdollAutomatically extends BaseObject {}

interface UnragdollAutomaticallyConstructor {
  readonly ClassName: 'UnragdollAutomatically';
  new (humanoid: Humanoid, serviceBag: ServiceBag): UnragdollAutomatically;
}

export const UnragdollAutomatically: PlayerHumanoidBinder<UnragdollAutomatically>;
