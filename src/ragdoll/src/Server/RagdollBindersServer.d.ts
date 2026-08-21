import { BinderProvider } from '@quenty/binder';
import { Ragdoll } from './Classes/Ragdoll';
import { Ragdollable } from './Classes/Ragdollable';
import { RagdollHumanoidOnDeath } from './Classes/RagdollHumanoidOnDeath';
import { RagdollHumanoidOnFall } from './Classes/RagdollHumanoidOnFall';
import { UnragdollAutomatically } from './Classes/UnragdollAutomatically';

export const RagdollBindersServer: BinderProvider<{
  Ragdoll: Ragdoll;
  Ragdollable: Ragdollable;
  RagdollHumanoidOnDeath: RagdollHumanoidOnDeath;
  RagdollHumanoidOnFall: RagdollHumanoidOnFall;
  UnragdollAutomatically: UnragdollAutomatically;
}>;
