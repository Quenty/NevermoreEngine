import { CameraState } from '../CameraState';
import { SummedCamera } from './SummedCamera';

export interface CameraEffect {
  CameraState: CameraState;
  __add: (camera: CameraEffect) => SummedCamera;
}

export type CameraLike = CameraEffect | CameraState;
