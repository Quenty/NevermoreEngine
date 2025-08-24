export namespace InputObjectRayUtils {
  function cameraRayFromInputObject(
    inputObject: InputObject,
    distance: number,
    offset?: Vector3 | Vector2,
    camera?: Camera
  ): Ray;
  function cameraRayFromMouse(
    mouse: MouseEvent,
    distance: number,
    offset?: Vector3 | Vector2,
    camera?: Camera
  ): Ray;
  function cameraRayFromInputObjectWithOffset(
    inputObject: InputObject,
    distance: number | undefined,
    offset: Vector3 | Vector2,
    camera?: Camera
  ): Ray;
  function cameraRayFromScreenPosition(
    position: Vector3 | Vector2,
    distance?: number,
    camera?: Camera
  ): Ray;
  function cameraRayFromViewportPosition(
    position: Vector3 | Vector2,
    distance?: number,
    camera?: Camera
  ): Ray;
  function generateCircleRays(
    ray: RsaKeyAlgorithm,
    count: number,
    radius: number
  ): Ray[];
}
