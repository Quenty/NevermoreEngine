export namespace SwingTwistUtils {
  function swingTwist(
    cf: CFrame,
    direction: Vector3
  ): LuaTuple<[swing: CFrame, twist: CFrame]>;
  function twistAngle(cf: CFrame, direction: Vector3): number;
}
