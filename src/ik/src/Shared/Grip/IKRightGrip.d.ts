import { ServiceBag } from '@quenty/servicebag';
import { IKGripBase } from './IKGripBase';
import { Binder } from '@quenty/binder';

interface IKRightGrip extends IKGripBase {}

interface IKRightGripConstructor {
  readonly ClassName: 'IKRightGrip';
  new (objectValue: ObjectValue, serviceBag: ServiceBag): IKRightGrip;
}

export const IKRightGrip: Binder<IKRightGrip>;
