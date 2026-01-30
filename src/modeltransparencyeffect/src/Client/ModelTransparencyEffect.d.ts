import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface ModelTransparencyEffect extends BaseObject {
  SetAcceleration(acceleration: number): void;
  SetTransparency(transparency: number, doNotAnimate?: boolean): void;
  IsDoneAnimating(): boolean;
  FinishTransparencyAnimation(callback: () => void): void;
}

interface ModelTransparencyEffectConstructor {
  readonly ClassName: 'ModelTransparencyEffect';
  new (
    serviceBag: ServiceBag,
    adornee: Instance,
    transparencyServiceMethodName?:
      | 'SetTransparency'
      | 'SetLocalTransparencyModifier'
  ): ModelTransparencyEffect;
}

export const ModelTransparencyEffect: ModelTransparencyEffectConstructor;
