import { CameraState } from '../CameraState';
import { CameraEffect } from './CameraEffectUtils';

interface OverrideDefaultCameraToo extends CameraEffect {
  BaseCamera: CameraEffect;
  DefaultCamera: CameraEffect;
  Predicate?: (cameraState: CameraState) => boolean;
}

interface OverrideDefaultCameraTooConstructor {
  readonly ClassName: 'OverrideDefaultCameraToo';
  new (
    baseCamera: CameraEffect,
    defaultCamera: CameraEffect,
    predicate: (cameraState: CameraState) => boolean
  ): OverrideDefaultCameraToo;
}

export const OverrideDefaultCameraToo: OverrideDefaultCameraTooConstructor;
