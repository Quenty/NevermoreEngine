import { Octree } from './Octree';

interface OctreeNode<T> {
  KNearestNeighborsSearch(
    k: number,
    radius: number
  ): LuaTuple<[objects: T[], distancesSquared: number[]]>;
  GetObject(): T;
  RadiusSearch(
    radius: number
  ): LuaTuple<[objects: T[], distancesSquared: number[]]>;
  GetPosition(): Vector3 | undefined;
  GetRawPosition(): LuaTuple<
    [px: number | undefined, py: number | undefined, pz: number | undefined]
  >;
  SetPosition(position: Vector3): void;
  Destroy(): void;
}

interface OctreeNodeConstructor {
  readonly ClassName: 'OctreeNode';
  new <T>(octree: Octree<T>, object: T): OctreeNode<T>;
}

export const OctreeNode: OctreeNodeConstructor;
