import { QFrame } from '../../../../qframe/src/Shared/QFrame';

type CameraFrame = {};

interface CameraFrameConstructor {
  readonly ClassName: 'CameraFrame';
  new (qFrame: QFrame, fieldOfView: number): CameraFrame;

  isCameraFrame: (value: any) => value is CameraFrame;
}

export const CameraFrame: CameraFrameConstructor;
