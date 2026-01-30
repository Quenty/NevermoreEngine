import { CameraState } from '../CameraState';

export interface CameraEffect {
  CameraState: CameraState;
}

export type CameraLike = CameraEffect | CameraState;
