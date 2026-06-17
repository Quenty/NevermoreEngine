import { CameraFrame } from '../Utility/CameraFrame';
import { CameraEffect } from './CameraEffectUtils';

interface PushCamera extends CameraEffect {
  CFrame: CameraFrame;
  set DefaultCFrame(value: CameraFrame);
  AngleY: number;
  AngleX: number;
  AngleXZ: number;
  MinY: number;
  MaxY: number;
  LastUpdateTime: number;
  readonly PercentFadedCurved: number;
  readonly PercentFaded: number;
  readonly LookVector: Vector3;
  Reset(): void;
  StopRotateBack(): void;
  RotateXY(xzrotVector: Vector2): void;
}

interface PushCameraConstructor {
  readonly ClassName: 'PushCamera';
  new (): PushCamera;
}

export const PushCamera: PushCameraConstructor;
