import { QFrame } from '../../../../qframe/src/Shared/QFrame';

interface CameraFrame {
  CFrame: CFrame;
  Position: Vector3;
  FieldOfView: number;
  QFrame: QFrame;

  __add(other: CameraFrame): CameraFrame;
  __sub(other: CameraFrame): CameraFrame;
  __unm(): CameraFrame;
  __mul(scalar: number): CameraFrame;
  __div(scalar: number): CameraFrame;
  __pow(scalar: number): CameraFrame;
  __eq(other: CameraFrame): boolean;
}

interface CameraFrameConstructor {
  readonly ClassName: 'CameraFrame';
  new (qFrame?: QFrame, fieldOfView?: number): CameraFrame;

  isCameraFrame: (value: unknown) => value is CameraFrame;
}

export const CameraFrame: CameraFrameConstructor;
