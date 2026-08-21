import { BaseObject } from '@quenty/baseobject';
import { Binder } from '@quenty/binder';
import { ServiceBag } from '@quenty/servicebag';

export interface RagdollClient extends BaseObject {}

export interface RagdollClientConstructor {
  readonly ClassName: 'RagdollClient';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RagdollClient;
}

export const RagdollClient: Binder<RagdollClient>;
