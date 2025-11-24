import { CameraState } from '../CameraState';
import { CameraEffect } from './CameraEffectUtils';

interface SummedCamera extends CameraEffect {
  readonly CameraAState: CameraState;
  readonly CameraBState: CameraState;
  SetMode(mode: 'World' | 'Relative'): this;
  __add(other: CameraEffect): SummedCamera;
  __sub(other: CameraEffect): CameraEffect;
}

interface SummedCameraConstructor {
  readonly ClassName: 'SummedCamera';
  new (cameraA: CameraEffect, cameraB: CameraEffect): SummedCamera;
}

export const SummedCamera: SummedCameraConstructor;
