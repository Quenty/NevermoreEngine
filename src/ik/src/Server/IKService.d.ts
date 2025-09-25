import { ServiceBag } from '@quenty/servicebag';
import { IKRig } from './Rig/IKRig';
import { Promise } from '@quenty/promise';

export interface IKService {
  readonly ServiceName: 'IKService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetRig(humanoid: Humanoid): IKRig | undefined;
  PromiseRig(humanoid: Humanoid): Promise<IKRig>;
  RemoveRig(humanoid: Humanoid): void;
  UpdateServerRigTarget(humanoid: Humanoid, target: Vector3): void;
  Destroy(): void;
}
