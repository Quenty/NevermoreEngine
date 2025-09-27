export interface CameraInfo {
  cframe: CFrame;
  viewPortSize: Vector2;
  fieldOfView: number;
}

export namespace CameraInfoUtils {
  function createCameraInfo(
    cframe: CFrame,
    viewPortSize: Vector2,
    fieldOfView: number
  ): CameraInfo;
  function fromCamera(camera: Camera): CameraInfo;
  function isCameraInfo(value: unknown): value is CameraInfo;
}
