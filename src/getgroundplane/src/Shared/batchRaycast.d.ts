export const batchRaycast: (
  originList: Vector3[],
  directionList: Vector3[],
  ignoreListWorkingEnvironment: Instance[],
  ignoreFunc: (instance: Instance) => boolean,
  keepIgnoreListChanges: boolean
) => RaycastResult[];
