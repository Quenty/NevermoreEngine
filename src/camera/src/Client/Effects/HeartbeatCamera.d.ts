import { CameraEffect } from './CameraEffectUtils';

interface HeartbeatCamera extends CameraEffect {
  ForceUpdateCache(): void;
}

interface HeartbeatCameraConstructor {
  readonly ClassName: 'HeartbeatCamera';
  new (camera: CameraEffect): HeartbeatCamera;
}

export const HeartbeatCamera: HeartbeatCameraConstructor;
