import { CameraEffect } from './CameraEffectUtils';

interface TrackCamera extends CameraEffect {
  CameraSubject?: BasePart | Model | Attachment | Humanoid;
  FieldOfView?: number;
}

interface TrackCameraConstructor {
  readonly ClassName: 'TrackCamera';
  new (cameraSubject?: BasePart | Model | Attachment | Humanoid): TrackCamera;
}

export const TrackCamera: TrackCameraConstructor;
