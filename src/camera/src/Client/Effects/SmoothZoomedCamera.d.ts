import { Spring } from '@quenty/spring';
import { CameraEffect } from './CameraEffectUtils';

interface SmoothZoomedCamera extends CameraEffect {
  Zoom: number;
  Speed: number;
  Range: number;
  MaxZoom: number;
  MinZoom: number;
  Target: number;
  Value: number;
  Velocity: number;
  TargetZoom: number;
  Spring: Spring<number>;
  TargetPercentZoom: number;
  PercentZoom: number;
  Damper: number;
  readonly HasReachedTarget: boolean;

  ZoomIn(value: number, min?: number, max?: number): void;
  Impulse(value: number): void;
}

interface SmoothZoomedCameraConstructor {
  readonly ClassName: 'SmoothZoomedCamera';
  new (): SmoothZoomedCamera;
}

export const SmoothZoomedCamera: SmoothZoomedCameraConstructor;
