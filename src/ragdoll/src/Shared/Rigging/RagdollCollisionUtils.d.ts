import { Maid } from '@quenty/maid';

export namespace RagdollCollisionUtils {
  function getCollisionData(
    rigType: Enum.HumanoidRigType
  ): [part0Name: string, part1Name: string][];
  function preventCollisionAmongOthers(character: Model, part: BasePart): Maid;
  function ensureNoCollides(
    character: Model,
    rigType: Enum.HumanoidRigType
  ): Maid;
}
