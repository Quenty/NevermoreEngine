import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Mountable } from '@quenty/valueobject';

interface AnimationSlotPlayer extends BaseObject {
  SetDefaultFadeTime(defaultFadeTime: number): void;
  SetDefaultAnimationPriority(
    defaultAnimationPriority: Enum.AnimationPriority | undefined
  ): void;
  SetAnimationTarget(animationTarget: Mountable<Instance>): void;
  PromiseStopped(): Promise<true | undefined>;
  AdjustSpeed(id: string | number, speed: number): void;
  AdjustWeight(id: string, weight: number, fadeTime?: number): void;
  Play(
    id: string | number,
    fadeTime?: number,
    weight?: number,
    speed?: number,
    priority?: Enum.AnimationPriority
  ): () => void;
  Stop(): void;
}

interface AnimationSlotPlayerConstructor {
  readonly ClassName: 'AnimationSlotPlayer';
  new (animationTarget?: Mountable<Instance>): AnimationSlotPlayer;
}

export const AnimationSlotPlayer: AnimationSlotPlayerConstructor;
