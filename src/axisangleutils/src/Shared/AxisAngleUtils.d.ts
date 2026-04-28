export namespace AxisAngleUtils {
  function toCFrame(axisAngle: Vector3, position?: Vector3): CFrame;
  function fromCFrame(
    cframe: CFrame
  ): LuaTuple<[axisAngle: Vector3, position: Vector3]>;
}
