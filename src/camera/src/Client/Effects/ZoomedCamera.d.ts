import { CameraEffect } from './CameraEffectUtils';

interface ZoomedCamera extends CameraEffect {
  Zoom: number;
  TargetZoom: number;
  MinZoom: number;
  MaxZoom: number;

  ZoomIn(value: number, min?: number, max?: number): void;
}

interface ZoomedCameraConstructor {
  readonly ClassName: 'ZoomedCamera';
  new (): ZoomedCamera;
}

export const ZoomedCamera: ZoomedCameraConstructor;
