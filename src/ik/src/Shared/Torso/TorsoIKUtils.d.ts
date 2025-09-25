export namespace TorsoIKUtils {
  function getTargetAngles(
    rootPart: BasePart,
    target: Vector3
  ): LuaTuple<[waistY: number, headY: number, waistZ: number, headZ: number]>;
}
