import { OctreeNode } from './OctreeNode';
import { OctreeRegion } from './OctreeRegionUtils';

interface Octree<T> {
  GetAllNodes(): OctreeNode<T>[];
  CreateNode(position: Vector3, object: T): OctreeNode<T>;
  RadiusSearch(
    position: Vector3,
    radius: number
  ): LuaTuple<[objects: T[], distancesSquared: number[]]>;
  KNearestNeighborsSearch(
    position: Vector3,
    k: number,
    radius: number
  ): LuaTuple<[objects: T[], distancesSquared: number[]]>;
  GetOrCreateLowestSubRegion(
    px: number,
    py: number,
    pz: number
  ): OctreeRegion<T>;
}

interface OctreeConstructor {
  readonly ClassName: 'Octree';
  new <T>(): Octree<T>;
}

export const Octree: OctreeConstructor;
