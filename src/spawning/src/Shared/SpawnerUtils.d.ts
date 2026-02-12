import { Raycaster } from '@quenty/raycaster';

export namespace SpawnerUtils {
  function getSpawnLocation(
    spawnPart: BasePart,
    raycaster: Raycaster
  ): LuaTuple<[position: Vector3, raycastResult?: RaycastResult]>;
}
