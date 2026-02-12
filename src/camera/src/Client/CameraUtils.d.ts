export namespace CameraUtils {
  function getCubeoidDiameter(size: Vector3): number;
  function fitBoundingBoxToCamera(
    size: Vector3,
    fovDeg: number,
    aspectRatio: number
  ): number;
  function fitSphereToCamera(
    radius: number,
    fovDeg: number,
    aspectRatio: number
  ): number;
  function isOnScreen(camera: Camera, position: Vector3): boolean;
}
