import { Maid } from '@quenty/maid';
import { Observable } from '@quenty/rx';

export namespace RxRagdollUtils {
  function observeRigType(humanoid: Humanoid): Observable<Enum.HumanoidRigType>;
  function observeCharacterBrio(humanoid: Humanoid): Observable<Model>;
  function suppressRootPartCollision(character: Model): Maid;
  function enforceHeadCollision(character: Model): Maid;
  function enforceHumanoidStateMachineOff(
    character: Model,
    humanoid: Humanoid
  ): Maid;
  function enforceLimbCollisions(character: Model): Maid;
  function runLocal(humanoid: Humanoid): Maid;
  function enforceHumanoidState(humanoid: Humanoid): Maid;
}
