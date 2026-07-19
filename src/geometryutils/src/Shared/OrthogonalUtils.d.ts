export namespace OrthogonalUtils {
  function decomposeCFrameToVectors(cframe: CFrame): Vector3[];
  function getClosestVector(
    options: Vector3[],
    unitVector: Vector3
  ): Vector3 | undefined;
  function snapCFrameTo(cframe: CFrame, snapToCFrame: CFrame): CFrame;
}
