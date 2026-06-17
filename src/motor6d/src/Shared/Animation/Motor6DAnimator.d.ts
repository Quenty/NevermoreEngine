import { BaseObject } from '@quenty/baseobject';
import { Motor6DTransformer } from './Motor6DTransformer';

interface Motor6DAnimator extends BaseObject {
  Push(transformer: Motor6DTransformer): void;
}

interface Motor6DAnimatorConstructor {
  readonly ClassName: 'Motor6DAnimator';
  new (motor6D: Motor6D): Motor6DAnimator;
}

export const Motor6DAnimator: Motor6DAnimatorConstructor;
