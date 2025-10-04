export namespace CompiledBoundingBoxUtils {
  function compileBBox(cframe: CFrame, size: Vector3): CFrame;
  function testPointBBox(point: Vector3, bbox: CFrame): boolean;
}
