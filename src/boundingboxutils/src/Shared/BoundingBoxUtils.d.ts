export interface PartLike {
  CFrame: CFrame;
  Size: Vector3;
}

export namespace BoundingBoxUtils {
  function getPartsBoundingBox(
    parts: PartLike[],
    relativeTo?: CFrame
  ): LuaTuple<[size: Vector3, position: Vector3]>;
  function clampPointToBoundingBox(
    cframe: CFrame,
    size: Vector3,
    point: Vector3
  ): LuaTuple<[clampedPoint: Vector3, centerPoint: Vector3]>;
  function pushPointToLieOnBoundingBox(
    cframe: CFrame,
    size: Vector3,
    point: Vector3
  ): LuaTuple<[pushedPoint: Vector3, centerPoint: Vector3]>;
  function getChildrenBoundingBox(
    parent: Instance,
    relativeTo?: CFrame
  ): LuaTuple<[size?: Vector3, position?: Vector3]>;
  function axisAlignedBoxSize(cframe: CFrame, size: Vector3): Vector3;
  function getBoundingBox(
    data: PartLike[],
    relativeTo?: CFrame
  ): LuaTuple<[size?: Vector3, position?: Vector3]>;
  function inBoundingBox(
    cframe: CFrame,
    size: Vector3,
    testPosition: Vector3
  ): boolean;
  function inCylinderBoundingBox(
    cframe: CFrame,
    Size: Vector3,
    testPosition: Vector3
  ): boolean;
  function inBallBoundingBox(
    cframe: CFrame,
    size: Vector3,
    testPosition: Vector3
  ): boolean;
}
