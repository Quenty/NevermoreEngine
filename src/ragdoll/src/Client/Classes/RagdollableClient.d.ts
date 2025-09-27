import { ServiceBag } from '@quenty/servicebag';
import { Binder } from '@quenty/binder';
import { RagdollableBase } from '../../Shared/Classes/RagdollableBase';

export interface RagdollableClient extends RagdollableBase {}

export interface RagdollableClientConstructor {
  readonly ClassName: 'RagdollableClient';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RagdollableClient;
}

export const RagdollableClient: Binder<RagdollableClient>;
