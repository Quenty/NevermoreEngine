export namespace PhysicsUtils {
  function getConnectedParts(part: BasePart): BasePart[];
  function getMass(parts: BasePart[]): number;
  function estimateBuoyancyContribution(
    parts: BasePart[]
  ): LuaTuple<[buoyancy: number, mass: number, volume: number]>;
  function getCenterOfMass(
    parts: BasePart[]
  ): LuaTuple<[position: Vector3, mass: number]>;
  function momentOfInertia(
    part: BasePart,
    axis: Vector3,
    origin: Vector3
  ): number;
  function bodyMomentOfInertia(
    parts: BasePart[],
    axis: Vector3,
    origin: Vector3
  ): number;
  function applyForce(
    part: BasePart,
    force: Vector3,
    forcePosition: Vector3
  ): void;
  function acceleratePart(
    part: BasePart,
    emittingPart: BasePart,
    acceleration: Vector3
  ): void;
}
