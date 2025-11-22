import { ServiceBag } from '@quenty/servicebag';

export interface RagdollService {
  readonly ServiceName: 'RagdollService';
  Init(serviceBag: ServiceBag): void;
  SetRagdollOnFall(ragdollOnFall: boolean): void;
  SetRagdollOnDeath(ragdollOnDeath: boolean): void;
  SetUnragdollAutomatically(unragdollAutomatically: boolean): void;
}
