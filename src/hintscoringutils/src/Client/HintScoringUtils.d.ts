import { Raycaster } from '@quenty/raycaster';

export namespace HintScoringUtils {
  function getHumanoidPositionDirection(
    humanoid: Humanoid
  ): LuaTuple<[position: Vector3, lookVector: Vector3]>;
  function getAdorneeInRegionSet(
    position: Vector3,
    radius: number,
    ignoreList: Instance[],
    getAdorneeFunction: (instance: Instance) => Instance | undefined
  ): Map<Instance, true>;
  function debugScore(adornee: Instance, score: number): void;
  function raycastToAdornee(
    raycaster: Raycaster,
    humanoidCenter: Vector3,
    adornee: Instance,
    closestBoundingBoxPoint: Vector3,
    extraDistance: number
  ): Vector3 | undefined;
  function clampToBoundingBox(
    adornee: Instance,
    humanoidCenter: Vector3
  ): LuaTuple<
    [clampedPoint: Vector3 | undefined, centerPoint: Vector3 | undefined]
  >;
  function scoreAdornee(
    adornee: Instance,
    raycaster: Raycaster,
    humanoidCenter: Vector3,
    humanoidLookVector: Vector3,
    maxViewRadius: number,
    maxTriggerRadius: number,
    maxViewAngle: number,
    maxTriggerAngle: number,
    isLineOfSightRequired: boolean
  ): number | undefined;
  function scoreDist(
    distance: number,
    maxViewDistance: number,
    maxTriggerRadius: number
  ): number | undefined;
  function scoreAngle(
    angle: number,
    maxViewAngle: number,
    maxTriggerAngle: number
  ): number | undefined;
}
