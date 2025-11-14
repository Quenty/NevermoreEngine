import { SmoothRotatedCamera } from '../Effects/SmoothRotatedCamera';
import { SmoothZoomedCamera } from '../Effects/SmoothZoomedCamera';

interface CameraControls {
  SetGamepadRotationAcceleration(acceleration: number): void;
  GetKey(): string;
  IsEnabled(): boolean;
  Enable(): void;
  Disable(): void;
  BeginDrag(beginInputObject: InputObject): void;
  SetZoomedCamera(zoomedCamera: SmoothZoomedCamera): this;
  SetRotatedCamera(rotatedCamera: SmoothRotatedCamera): this;
  SetVelocityStrength(strength: number): void;
  Destroy(): void;
}

interface CameraControlsConstructor {
  readonly ClassName: 'CameraControls';
  new (
    zoomedCamera: SmoothZoomedCamera,
    rotatedCamera: SmoothRotatedCamera
  ): CameraControls;

  MOUSE_SENSITIVITY: Vector2;
}

export const CameraControls: CameraControlsConstructor;
