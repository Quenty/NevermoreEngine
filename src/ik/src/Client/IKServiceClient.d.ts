import { ServiceBag } from '@quenty/servicebag';
import { IKRigClient } from './Rig/IKRigClient';
import { Promise } from '@quenty/promise';
import { IKRigAimerLocalPlayer } from './Rig/IKRigAimerLocalPlayer';

export interface IKServiceClient {
  readonly ServiceName: 'IKServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetRig(humanoid: Humanoid): IKRigClient | undefined;
  PromiseRig(humanoid: Humanoid): Promise<IKRigClient>;
  SetAimPosition(position: Vector3 | undefined, priority?: number): void;
  SetLookAround(lookAround: boolean): void;
  GetLocalAimer(): IKRigAimerLocalPlayer | undefined;
  GetLocalPlayerRig(): IKRigClient | undefined;
  Destroy(): void;
}
