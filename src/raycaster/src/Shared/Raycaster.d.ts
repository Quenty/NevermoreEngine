interface Raycaster {
  readonly IgnoreList: Instance[];
  Filter: (raycastResult: RaycastResult) => boolean;
  IgnoreWater: boolean;
  MaxCasts: number;

  Ignore(tableOrInstance: Instance | Instance[]): void;
  FindPartOnRay(ray: Ray): RaycastResult | undefined;
}

interface RaycasterConstructor {
  readonly ClassName: 'Raycaster';
  new (doIgnoreFunction?: (raycastResult: RaycastResult) => boolean): Raycaster;
}

export const Raycaster: RaycasterConstructor;
