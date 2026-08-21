export namespace AdorneeUtils {
  function getCenter(adornee: Instance): Vector3 | undefined;
  function getBoundingBox(
    adornee: Instance
  ): LuaTuple<[cframe?: CFrame, size?: Vector3]>;
  function isPartOfAdornee(adornee: Instance, part: BasePart): boolean;
  function getParts(adornee: Instance): BasePart[];
  function getAlignedSize(adornee: Instance): Vector3 | undefined;
  function getPartCFrame(adornee: Instance): CFrame | undefined;
  function getPartPosition(adornee: Instance): Vector3 | undefined;
  function getPartVelocity(adornee: Instance): Vector3 | undefined;
  function getPart(adornee: Instance): BasePart | undefined;
  function getRenderAdornee(adornee: Instance): Instance | undefined;
}
