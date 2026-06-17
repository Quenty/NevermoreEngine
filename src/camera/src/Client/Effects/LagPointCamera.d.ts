import { Spring } from '@quenty/spring';
import { CameraState } from '../CameraState';
import { CameraEffect } from './CameraEffectUtils';

interface LagPointCamera extends CameraEffect {
  readonly Origin: CameraState;
  readonly FocusPosition: Vector3;
  FocusSpring: Spring<Vector3>;
  OriginCamera: CameraEffect;
  FocusCamera: CameraEffect;
  Speed: number;
  Damper: number;
  Velocity: Vector3;
  LastFocusUpdate: number;
}

interface LagPointCameraConstructor {
  readonly ClassName: 'LagPointCamera';
  new (originCamera: CameraEffect, focusCamera: CameraEffect): LagPointCamera;
}

export const LagPointCamera: LagPointCameraConstructor;
