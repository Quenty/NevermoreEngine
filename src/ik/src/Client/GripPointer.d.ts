import { BaseObject } from '@quenty/baseobject';
import { IKRigClient } from './Rig/IKRigClient';

interface GripPointer extends BaseObject {
  SetLeftGrip(leftGrip: Attachment): void;
  SetRightGrip(rightGrip: Attachment): void;
}

interface GripPointerConstructor {
  readonly ClassName: 'GripPointer';
  new (ikRig: IKRigClient): GripPointer;
}

export const GripPointer: GripPointerConstructor;
