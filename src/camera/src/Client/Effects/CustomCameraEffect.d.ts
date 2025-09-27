import { CameraState } from '../CameraState';
import { CameraEffect } from './CameraEffectUtils';

interface CustomCameraEffect extends CameraEffect {}

interface CustomCameraEffectConstructor {
  readonly ClassName: 'CustomCameraEffect';
  new (getCurrentStateFunc: () => CameraState): CustomCameraEffect;
}

export const CustomCameraEffect: CustomCameraEffectConstructor;
