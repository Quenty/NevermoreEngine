import { CameraFrame } from './Utility/CameraFrame';

interface CameraState {
  CFrame: CFrame;
  Position: Vector3;
  CameraFrame: CameraFrame;
  CameraFrameDerivative: CameraFrame;
  Velocity: Vector3;
  FieldOfView: number;

  Set(camera: Camera): void;
}

interface CameraStateConstructor {
  readonly ClassName: 'CameraState';
  new (
    cameraFrame?: CameraFrame | Camera,
    cameraFrameDerivative?: CameraFrame
  ): CameraState;
  isCameraState: (value: unknown) => value is CameraState;
}

export const CameraState: CameraStateConstructor;
