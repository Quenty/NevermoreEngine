export namespace Region3Utils {
  function fromPositionSize(position: Vector3, size: Vector3): Region3;
  function fromBox(cframe: CFrame, size: Vector3): Region3;
  function fromRadius(position: Vector3, radius: number): Region3;
}
