import { Raycaster } from '@quenty/raycaster';

export namespace GetPercentExposedUtils {
  const RAY_COUNT: 314;

  function search(
    point: Vector3,
    radius: number,
    raycaster?: Raycaster
  ): Map<BasePart, number>;
}
