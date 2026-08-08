import { CameraEffect } from './CameraEffectUtils';
import { FadingCamera } from './FadingCamera';

interface InverseFader extends CameraEffect {}

interface InverseFaderConstructor {
  readonly ClassName: 'InverseFader';
  new (camera: CameraEffect, fader: FadingCamera): InverseFader;
}

export const InverseFader: InverseFaderConstructor;
