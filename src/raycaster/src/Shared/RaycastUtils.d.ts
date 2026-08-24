export namespace RaycastUtils {
  function raycastSingleExit(
    origin: Vector3,
    direction: Vector3,
    part: BasePart
  ): RaycastResult | undefined;
  function ignoreCanCollideFalse(part: BasePart): boolean;
  function raycast(
    origin: Vector3,
    direction: Vector3,
    ignoreListWorkingEnvironment: Instance[],
    ignoreFunc: (raycastResult: RaycastResult) => boolean,
    keepIgnoreListChanges?: boolean,
    ignoreWater?: boolean
  ): RaycastResult | undefined;
}
