import { CameraEffect } from './CameraEffectUtils';

interface ImpulseCamera extends CameraEffect {
  Impulse(velocity: Vector3, speed?: number, damper?: number): void;
  ImpulseRandom(velocity: Vector3, speed?: number, damper?: number): void;
}

interface ImpulseCameraConstructor {
  readonly ClassName: 'ImpulseCamera';
  new (): ImpulseCamera;
}

export const ImpulseCamera: ImpulseCameraConstructor;
