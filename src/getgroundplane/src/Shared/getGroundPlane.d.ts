export const getGroundPlane: (
  basis: CFrame,
  radius: number,
  length: number,
  sampleCount: number,
  ignoreList: Instance[],
  ignoreFunc: (instance: Instance) => boolean
) => LuaTuple<[position: Vector3, normal: Vector3]>;
