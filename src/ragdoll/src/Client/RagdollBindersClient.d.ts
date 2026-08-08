import { BinderProvider } from '@quenty/binder';
import { RagdollClient } from './Classes/RagdollClient';
import { RagdollableClient } from './Classes/RagdollableClient';
import { RagdollHumanoidOnDeathClient } from './Classes/RagdollHumanoidOnDeathClient';
import { RagdollHumanoidOnFallClient } from './Classes/RagdollHumanoidOnFallClient';

export const RagdollBindersClient: BinderProvider<{
  Ragdoll: RagdollClient;
  Ragdollable: RagdollableClient;
  RagdollHumanoidOnDeath: RagdollHumanoidOnDeathClient;
  RagdollHumanoidOnFall: RagdollHumanoidOnFallClient;
}>;
