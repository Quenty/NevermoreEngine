import { Spring } from '@quenty/spring';
import { CameraEffect } from '../CameraEffectUtils';

interface FadeBetweenCamera extends CameraEffect {
  Damper: number;
  Value: number;
  Speed: number;
  Target: number;
  Velocity: number;
  CameraA: CameraEffect;
  CameraStateA: CameraEffect;
  CameraB: CameraEffect;
  CameraStateB: CameraEffect;
  readonly HasReachedTarget: boolean;
  readonly Spring: Spring<number>;
}

interface FadeBetweenCameraConstructor {
  readonly ClassName: 'FadeBetweenCamera';
  new (cameraA: CameraEffect, cameraB: CameraEffect): FadeBetweenCamera;
}

export const FadeBetweenCamera: FadeBetweenCameraConstructor;
