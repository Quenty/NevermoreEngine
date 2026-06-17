export namespace CFrameUtils {
  function lookAt(
    position: Vector3,
    target: Vector3,
    upVector?: Vector3
  ): CFrame;
  function cframeFromTo(a: Vector3, b: Vector3): CFrame;
  function redirectLocalAxis(
    cframe: CFrame,
    localAxis: Vector3,
    worldGoal: Vector3
  ): CFrame;
  function axisAngleToCFrame(axisAngle: Vector3, position?: Vector3): CFrame;
  function fromUpRight(
    position: Vector3,
    upVector: Vector3,
    rightVector: Vector3
  ): CFrame | undefined;
  function scalePosition(cframe: CFrame, scale: number): CFrame;
  function reflect(vector: Vector3, unitNormal: Vector3): Vector3;
  function mirror(cframe: CFrame, point?: Vector3, normal?: Vector3): CFrame;
  function areClose(a: CFrame, b: CFrame, epsilon: number): boolean;
}
