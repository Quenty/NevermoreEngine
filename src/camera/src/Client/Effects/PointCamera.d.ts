import { CameraState } from '../CameraState';
import { CameraEffect } from './CameraEffectUtils';

interface PointCamera extends CameraEffect {
  OriginCamera: CameraEffect;
  FocusCamera: CameraEffect;
  readonly Focus: CameraState;
  readonly Origin: CameraState;
}

interface PointCameraConstructor {
  readonly ClassName: 'PointCamera';
  new (originCamera: CameraEffect, focusCamera: CameraEffect): PointCamera;
}

export const PointCamera: PointCameraConstructor;
