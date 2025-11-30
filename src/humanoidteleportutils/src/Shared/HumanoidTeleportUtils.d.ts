import { Raycaster } from '@quenty/raycaster';

export namespace HumanoidTeleportUtils {
  function identifySafePosition(
    position: Vector3,
    raycaster: Raycaster
  ): LuaTuple<
    [success: true, position: Vector3] | [success: false, position: undefined]
  >;
  function teleportRootPart(
    humanoid: Humanoid,
    rootPart: BasePart,
    position: Vector3
  ): void;
  function teleportParts(
    humanoid: Humanoid,
    rootPart: BasePart,
    parts: BasePart[],
    position: Vector3
  ): void;
  function tryTeleportCharacter(character: Model, position: Vector3): boolean;
  function getRootPartOffset(humanoid: Humanoid, rootPart: BasePart): Vector3;
}
