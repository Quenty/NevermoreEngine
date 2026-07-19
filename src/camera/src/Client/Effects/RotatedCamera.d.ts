import { CameraState } from '../CameraState';
import { CameraEffect } from './CameraEffectUtils';

interface RotatedCamera extends CameraEffect {
  CFrame: CFrame;
  CameraState: CameraState;
  AngleY: number;
  AngleX: number;
  AngleXZ: number;
  MinY: number;
  MaxY: number;
  readonly LookVector: Vector3;

  RotateXY(xzrotvector: Vector2): void;
}

interface RotatedCameraConstructor {
  readonly ClassName: 'RotatedCamera';
  new (): RotatedCamera;
}

export const RotatedCamera: RotatedCameraConstructor;
