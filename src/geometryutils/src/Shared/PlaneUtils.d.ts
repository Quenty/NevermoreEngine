export namespace PlaneUtils {
  function rayIntersection(
    origin: Vector3,
    normal: Vector3,
    rayOrigin: Vector3,
    unitRayDirection: Vector3
  ): LuaTuple<[position: Vector3 | undefined, distance: number | undefined]>;
}
