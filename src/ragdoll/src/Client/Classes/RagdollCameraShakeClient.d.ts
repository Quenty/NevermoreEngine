import { ServiceBag } from '@quenty/servicebag';
import { Binder } from '@quenty/binder';
import { BaseObject } from '@quenty/baseobject';

export interface RagdollCameraShakeClient extends BaseObject {}

export interface RagdollCameraShakeClientConstructor {
  readonly ClassName: 'RagdollCameraShakeClient';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RagdollCameraShakeClient;
}

export const RagdollCameraShakeClient: Binder<RagdollCameraShakeClient>;
