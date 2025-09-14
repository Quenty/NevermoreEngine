import { ServiceBag } from '@quenty/servicebag';

export interface RagdollService {
  Init(serviceBag: ServiceBag): void;
  SetRagdollOnFall(ragdollOnFall: boolean): void;
  SetRagdollOnDeath(ragdollOnDeath: boolean): void;
  SetUnragdollAutomatically(unragdollAutomatically: boolean): void;
}
