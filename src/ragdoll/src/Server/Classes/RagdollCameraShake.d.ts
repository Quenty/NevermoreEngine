import { ServiceBag } from '@quenty/servicebag';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';
import { BaseObject } from '@quenty/baseobject';

interface RagdollCameraShake extends BaseObject {}

interface RagdollCameraShakeConstructor {
  readonly ClassName: 'RagdollCameraShake';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RagdollCameraShake;
}

export const RagdollCameraShake: PlayerHumanoidBinder<RagdollCameraShake>;
