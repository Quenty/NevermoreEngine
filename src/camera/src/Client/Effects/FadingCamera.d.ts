import { Spring } from '../../../../spring/src/Shared/Spring';
import { CameraState } from '../CameraState';
import { CameraEffect, CameraLike } from './CameraEffectUtils';

interface FadingCamera extends CameraEffect {
  Damper: number;
  Value: number;
  Speed: number;
  Target: number;
  Spring: Spring<number>;
  Camera: CameraLike;
  readonly Velocity: number;
  readonly CameraState: CameraState;
  readonly HasReachedTarget: boolean;
}

interface FadingCameraConstructor {
  readonly ClassName: 'FadingCamera';
  new (camera: CameraLike): FadingCamera;
}

export const FadingCamera: FadingCameraConstructor;
