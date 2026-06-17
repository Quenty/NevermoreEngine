import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface ArmIKBase extends BaseObject {
  Grip(attachment: Attachment, priority?: number): void;
  UpdateTransformOnly(): void;
  Update(): void;
}

interface ArmIKBaseConstructor {
  readonly ClassName: 'ArmIKBase';
  new (humanoid: Humanoid, armName: string, serviceBag: ServiceBag): ArmIKBase;
}

export const ArmIKBase: ArmIKBaseConstructor;
