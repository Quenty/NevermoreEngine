import { ServiceBag } from '@quenty/servicebag';
import { IKGripBase } from './IKGripBase';
import { Binder } from '@quenty/binder';

interface IKLeftGrip extends IKGripBase {}

interface IKLeftGripConstructor {
  readonly ClassName: 'IKLeftGrip';
  new (objectValue: ObjectValue, serviceBag: ServiceBag): IKLeftGrip;
}

export const IKLeftGrip: Binder<IKLeftGrip>;
