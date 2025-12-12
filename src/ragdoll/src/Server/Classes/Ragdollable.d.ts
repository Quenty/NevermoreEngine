import { ServiceBag } from '@quenty/servicebag';
import { RagdollableBase } from '../../Shared/Classes/RagdollableBase';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';

interface Ragdollable extends RagdollableBase {}

interface RagdollableConstructor {
  readonly ClassName: 'Ragdollable';
  new (humanoid: Humanoid, serviceBag: ServiceBag): Ragdollable;
}

export const Ragdollable: PlayerHumanoidBinder<Ragdollable>;
