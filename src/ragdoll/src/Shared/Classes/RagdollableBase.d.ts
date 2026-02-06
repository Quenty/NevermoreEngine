import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { RxSignal } from '@quenty/rxsignal';

interface RagdollableBase extends BaseObject {
  Ragdolled: RxSignal<boolean>;
  Unragdolled: RxSignal<boolean>;

  Ragdoll(): void;
  Unragdoll(): void;
  ObserveIsRagdolled(): Observable<boolean>;
  IsRagdolled(): boolean;
}

interface RagdollableBaseConstructor {
  readonly ClassName: 'RagdollableBase';
  new (humanoid: Humanoid): RagdollableBase;
}

export const RagdollableBase: RagdollableBaseConstructor;
