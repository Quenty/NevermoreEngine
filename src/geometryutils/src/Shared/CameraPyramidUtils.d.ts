import { Maid } from '@quenty/maid';

export namespace CameraPyramidUtils {
  function rayIntersection(
    camera: Camera,
    rayOrigin: Vector3,
    unitRayDirection: Vector3,
    debugMaid?: Maid
  ): LuaTuple<[first: Vector3, second: Vector3]>;
}
