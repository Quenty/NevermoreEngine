import { Spring } from '@quenty/spring';
import { CameraEffect } from './CameraEffectUtils';

interface SmoothPositionCamera extends CameraEffect {
  Spring: Spring<Vector3>;
  Speed: number;
  BaseCamera: CameraEffect;
  Damper: number;
  Velocity: Vector3;
  Target: Vector3;
  Position: Vector3;
}

interface SmoothPositionCameraConstructor {
  readonly ClassName: 'SmoothPositionCamera';
  new (baseCamera: CameraEffect): SmoothPositionCamera;
}

export const SmoothPositionCamera: SmoothPositionCameraConstructor;
