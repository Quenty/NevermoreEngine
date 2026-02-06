import { Spring } from '@quenty/spring';
import { CameraEffect } from './CameraEffectUtils';
import { CameraState } from '../CameraState';

interface SmoothRotatedCamera extends CameraEffect {
  AngleX: number;
  AngleXZ: number;
  RenderAngleXZ: number;
  AngleY: number;
  CFrame: CFrame;
  TargetCFrame: CFrame;
  RenderAngleY: number;
  CameraState: CameraState;
  MaxY: number;
  MinY: number;
  Rotation: CFrame;
  Speed: number;
  ZoomGiveY: number;
  SpeedAngleX: number;
  SpeedAngleY: number;
  SpringX: Spring<number>;
  SpringY: Spring<number>;
  TargetAngleX: number;
  TargetAngleXZ: number;
  TargetAngleY: number;
  TargetXZ: number;

  RotateXY(xyRotateVector: Vector2): void;
  SnapIntoBounds(): void;
  GetPastBounds(angle: number): number;
}

interface SmoothRotatedCameraConstructor {
  readonly ClassName: 'SmoothRotatedCamera';
  new (): SmoothRotatedCamera;
}

export const SmoothRotatedCamera: SmoothRotatedCameraConstructor;
