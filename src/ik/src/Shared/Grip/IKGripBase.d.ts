import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { IKRigBase } from '../Rig/IKRigBase';

interface IKGripBase extends BaseObject {
  GetPriority(): number;
  GetAttachment(): Attachment | undefined;
  PromiseIKRig(): Promise<IKRigBase>;
}

interface IKGripBaseConstructor {
  readonly ClassName: 'IKGripBase';
  new (objectValue: ObjectValue, serviceBag: ServiceBag): IKGripBase;
}

export const IKGripBase: IKGripBaseConstructor;
