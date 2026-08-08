import { ServiceBag } from '@quenty/servicebag';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';
import { BaseObject } from '@quenty/baseobject';

interface RagdollHumanoidOnDeath extends BaseObject {}

interface RagdollHumanoidOnDeathConstructor {
  readonly ClassName: 'RagdollHumanoidOnDeath';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RagdollHumanoidOnDeath;
}

export const RagdollHumanoidOnDeath: PlayerHumanoidBinder<RagdollHumanoidOnDeath>;
