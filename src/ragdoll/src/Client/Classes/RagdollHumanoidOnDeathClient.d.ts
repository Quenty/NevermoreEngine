import { BaseObject } from '@quenty/baseobject';
import { Binder } from '@quenty/binder';
import { ServiceBag } from '@quenty/servicebag';

export interface RagdollHumanoidOnDeathClient extends BaseObject {}

export interface RagdollHumanoidOnDeathClientConstructor {
  readonly ClassName: 'RagdollHumanoidOnDeathClient';
  new (
    humanoid: Humanoid,
    serviceBag: ServiceBag
  ): RagdollHumanoidOnDeathClient;

  disableParticleEmittersAndFadeOutYielding: (
    character: Model,
    duration: number
  ) => void;
}

export const RagdollHumanoidOnDeathClient: Binder<RagdollHumanoidOnDeathClient>;
