import { BaseObject } from '@quenty/baseobject';
import { Binder } from '@quenty/binder';
import { ValueObject } from '@quenty/valueobject';

interface BindableRagdollHumanoidOnFall extends BaseObject {
  ShouldRagdoll: ValueObject<boolean>;

  ObserveIsFalling(): boolean;
}

interface GuiTriangleConstructor {
  readonly ClassName: 'BindableRagdollHumanoidOnFall';
  new (
    humanoid: Humanoid,
    ragdollBinder: Binder<unknown>
  ): BindableRagdollHumanoidOnFall;
}

export const BindableRagdollHumanoidOnFall: GuiTriangleConstructor;
