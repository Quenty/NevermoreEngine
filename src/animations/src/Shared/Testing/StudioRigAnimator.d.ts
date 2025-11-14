import { BaseObject } from '@quenty/baseobject';

interface StudioRigAnimator extends BaseObject {}

interface StudioRigAnimatorConstructor {
  readonly ClassName: 'StudioRigAnimator';
  new (animatorOrHumanoid: Animator | Humanoid): StudioRigAnimator;
}

export const StudioRigAnimator: StudioRigAnimatorConstructor;
