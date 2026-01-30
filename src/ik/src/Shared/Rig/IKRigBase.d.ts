import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';
import { TorsoIKBase } from '../Torso/TorsoIKBase';
import { ArmIKBase } from '../Arm/ArmIKBase';

interface IKRigBase extends BaseObject {
  Updating: Signal;
  GetLastUpdateTime(): number;
  GetPlayer(): Player | undefined;
  GetHumanoid(): Humanoid;
  Update(): void;
  UpdateTransformOnly(): void;
  PromiseTorso(): Promise<TorsoIKBase>;
  GetTorso(): TorsoIKBase;
  PromiseLeftArm(): Promise<ArmIKBase>;
  GetLeftArm(): ArmIKBase;
  PromiseRightArm(): Promise<ArmIKBase>;
  GetRightArm(): ArmIKBase;
}

interface IKRigBaseConstructor {
  readonly ClassName: 'IKRigBase';
  new (humanoid: Humanoid, serviceBag: ServiceBag): IKRigBase;
}

export const IKRigBase: IKRigBaseConstructor;
