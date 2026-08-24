import { BaseObject } from '@quenty/baseobject';

interface IKRigAimerLocalPlayer extends BaseObject {
  SetLookAround(lookAround: boolean): void;
  SetAimPosition(
    position: Vector3 | undefined,
    optionalPriority?: number
  ): void;
  PushReplicationRate(replicateRate: number): () => void;
  GetAimPosition(): Vector3 | undefined;
  UpdateStepped(): void;
}

interface IKRigAimerLocalPlayerConstructor {
  readonly ClassName: 'IKRigAimerLocalPlayer';
  new (): IKRigAimerLocalPlayer;
}

export const IKRigAimerLocalPlayer: IKRigAimerLocalPlayerConstructor;
