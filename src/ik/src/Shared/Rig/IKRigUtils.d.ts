import { Binder } from '@quenty/binder';

export namespace IKRigUtils {
  function getTimeBeforeNextUpdate(distance: number): number;
  function getPlayerIKRig<T>(binder: Binder<T>, player: Player): T | undefined;
}
