import { CameraStack } from './CameraStack';
import { CameraState } from './CameraState';
import { CameraEffect, CameraLike } from './Effects/CameraEffectUtils';
import { DefaultCamera } from './Effects/DefaultCamera';
import { ImpulseCamera } from './Effects/ImpulseCamera';

export interface CameraStackService {
  readonly ServiceName: 'CameraStackService';
  Init(): void;
  Start(): void;
  GetRenderPriority(): number;
  SetDoNotUseDefaultCamera(doNotUseDefaultCamera: boolean): void;
  PushDisable(): () => void;
  PrintCameraStack(): void;
  GetDefaultCamera(): CameraEffect;
  GetImpulseCamera(): ImpulseCamera;
  GetRawDefaultCamera(): DefaultCamera;
  GetTopCamera(): CameraLike;
  GetTopState(): CameraState | undefined;
  GetNewStateBelow(): ReturnType<CameraStack['GetNewStateBelow']>;
  GetIndex(): number | undefined;
  GetRawStack(): CameraLike[];
  GetCameraStack(): CameraStack;
  Remove(state: CameraEffect): void;
  Add(state: CameraEffect): void;
  Destroy(): void;
}
