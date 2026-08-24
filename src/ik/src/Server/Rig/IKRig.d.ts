import { ServiceBag } from '@quenty/servicebag';
import { IKRigBase } from '../../Shared/Rig/IKRigBase';
import { Binder } from '@quenty/binder';

interface IKRig extends IKRigBase {
  GetAimPosition(): Vector3 | undefined;
  SetAimPosition(position: Vector3 | undefined): void;
}

interface IKRigConstructor {
  readonly ClassName: 'IKRig';
  new (humanoid: Humanoid, serviceBag: ServiceBag): IKRig;
}

export const IKRig: Binder<IKRig>;
