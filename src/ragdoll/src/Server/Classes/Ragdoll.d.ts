import { ServiceBag } from '@quenty/servicebag';
import { Binder } from '@quenty/binder';
import { BaseObject } from '@quenty/baseobject';

interface Ragdoll extends BaseObject {}

interface RagdollConstructor {
  readonly ClassName: 'Ragdoll';
  new (humanoid: Humanoid, serviceBag: ServiceBag): Ragdoll;
}

export const Ragdoll: Binder<Ragdoll>;
