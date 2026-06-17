import { CameraEffect, CameraLike } from './CameraEffectUtils';

interface XZPlaneLockCamera extends CameraEffect {}

interface XZPlaneLockCameraConstructor {
  readonly ClassName: 'XZPlaneLockCamera';
  new (camera?: CameraLike): XZPlaneLockCamera;
}

export const XZPlaneLockCamera: XZPlaneLockCameraConstructor;
