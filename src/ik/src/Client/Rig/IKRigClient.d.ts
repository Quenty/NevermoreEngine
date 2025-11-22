import { Binder } from '@quenty/binder';
import { IKRigBase } from '../../Shared/Rig/IKRigBase';
import { IKRigAimerLocalPlayer } from './IKRigAimerLocalPlayer';

interface IKRigClient extends IKRigBase {
  GetPositionOrNil(): Vector3 | undefined;
  GetLocalPlayerAimer(): IKRigAimerLocalPlayer | undefined;
  GetAimPosition(): Vector3 | undefined;
}

interface IKRigClientConstructor {
  readonly ClassName: 'IKRigClient';
  new (): IKRigClient;
}

export const IKRigClient: Binder<IKRigClient>;
