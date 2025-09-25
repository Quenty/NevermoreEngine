import { BaseObject } from '@quenty/baseobject';
import { Binder } from '@quenty/binder';
import { PromiseRemoteEventMixin } from '@quenty/remoting';
import { ServiceBag } from '@quenty/servicebag';

export interface RagdollHumanoidOnFallClient
  extends BaseObject,
    PromiseRemoteEventMixin {}

export interface RagdollHumanoidOnFallClientConstructor {
  readonly ClassName: 'RagdollHumanoidOnFallClient';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RagdollHumanoidOnFallClient;
}

export const RagdollHumanoidOnFallClient: Binder<RagdollHumanoidOnFallClient>;
