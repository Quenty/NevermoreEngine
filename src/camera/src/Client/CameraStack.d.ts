import { CameraState } from './CameraState';
import { CameraEffect, CameraLike } from './Effects/CameraEffectUtils';

interface CameraStack {
  PushDisable(): () => void;
  PrintCameraStack(): void;
  GetTopCamera(): CameraLike | undefined;
  GetTopState(): CameraState | undefined;
  GetNewStateBelow(): LuaTuple<
    [customCameraEffect: CameraEffect, setState: (state: CameraState) => void]
  >;
  GetIndex(state: CameraLike): number | undefined;
  GetStack(): CameraLike[];
  Remove(state: CameraLike): void;
  Add(state: CameraLike): () => void;
}

interface CameraStackConstructor {
  readonly ClassName: 'CameraStack';
  new (): CameraStack;
  isCameraStack: (value: unknown) => value is CameraStack;
}

export const CameraStack: CameraStackConstructor;
