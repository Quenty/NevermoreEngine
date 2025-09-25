import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { IKRigBase } from './Rig/IKRigBase';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

export interface IKDataService {
  readonly ServiceName: 'IKDataService';
  Init(serviceBag: ServiceBag): void;
  PromiseRig(humanoid: Humanoid): Promise<IKRigBase>;
  ObserveRig(humanoid: Humanoid): Observable<IKRigBase>;
  ObserveRigBrio(humanoid: Humanoid): Observable<Brio<IKRigBase>>;
}
