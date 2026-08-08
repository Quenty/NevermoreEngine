import { OctreeNode } from './OctreeNode';

type OctreeVector3 = [px: number, py: number, pz: number];

type OctreeRegionHashMap<T> = { [key: number]: OctreeRegion<T>[] };

export interface OctreeRegion<T> {
  subRegions: OctreeRegion<T>[];
  lowerBounds: OctreeVector3;
  upperBounds: OctreeVector3;
  position: OctreeVector3;
  size: OctreeVector3;
  parent: OctreeRegion<T> | undefined;
  parentIndex: number | undefined;
  depth: number;
  nodes: Map<OctreeNode<T>, OctreeNode<T>>;
  node_count: number;
}

export namespace OctreeRegionUtils {
  function visualize(region: OctreeRegion<unknown>): Instance;
  function create<T>(
    px: number,
    py: number,
    pz: number,
    sx: number,
    sy: number,
    sz: number,
    parent?: OctreeRegion<T>,
    parentIndex?: number
  ): OctreeRegion<T>;
  function addNode<T>(
    lowestSubregion: OctreeRegion<T>,
    node: OctreeNode<T>
  ): void;
  function modeNode<T>(
    fromLowest: OctreeRegion<T>,
    toLowest: OctreeRegion<T>,
    node: OctreeNode<T>
  ): void;
  function removeNode<T>(
    lowestSubregion: OctreeRegion<T>,
    node: OctreeNode<T>
  ): void;
  function getSearchRadiusSquared(
    radius: number,
    diameter: number,
    epsilon: number
  ): number;
  function getNeighborsWithinRadius<T>(
    region: OctreeRegion<T>,
    radius: number,
    px: number,
    py: number,
    pz: number,
    objectsFound: T[],
    nodeDistances2: number[],
    maxDepth: number
  ): void;
  function getOrCreateSubRegionAtDepth<T>(
    region: OctreeRegion<T>,
    px: number,
    py: number,
    pz: number,
    maxDepth: number
  ): OctreeRegion<T>;
  function createSubRegion<T>(
    parentRegion: OctreeRegion<T>,
    parentIndex: number
  ): OctreeRegion<T>;
  function inRegionBounds<T>(
    region: OctreeRegion<T>,
    px: number,
    py: number,
    pz: number
  ): boolean;
  function getSubRegionIndex(
    region: OctreeRegion<unknown>,
    px: number,
    py: number,
    pz: number
  ): number;
  function getTopLevelRegionHash(cx: number, cy: number, cz: number): number;
  function getTopLevelRegionCellIndex(
    maxRegionSize: OctreeVector3,
    px: number,
    py: number,
    pz: number
  ): LuaTuple<[rpx: number, rpy: number, rpz: number]>;
  function getTopLevelRegionPosition(
    maxRegionSize: OctreeVector3,
    cx: number,
    cy: number,
    cz: number
  ): LuaTuple<[number, number, number]>;
  function areEqualTopRegions(
    region: OctreeRegion<unknown>,
    rpx: number,
    rpy: number,
    rpz: number
  ): boolean;
  function findRegion<T>(
    regionHashMap: OctreeRegionHashMap<T>,
    maxRegionSize: OctreeVector3,
    px: number,
    py: number,
    pz: number
  ): OctreeRegion<T> | undefined;
  function getOrCreateRegion<T>(
    regionHashMap: OctreeRegionHashMap<T>,
    maxRegionSize: OctreeVector3,
    px: number,
    py: number,
    pz: number
  ): OctreeRegion<T>;
}
