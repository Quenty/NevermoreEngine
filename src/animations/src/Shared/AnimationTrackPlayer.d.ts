import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';
import { Mountable } from '@quenty/valueobject';

interface AnimationTrackPlayer extends BaseObject {
  KeyframeReached: Signal;
  SetAnimationId(animationId: string | number): void;
  GetAnimationId(): string | number | undefined;
  SetAnimationTarget(target: Mountable<Instance> | undefined): void;
  SetWeightTargetIfNotSet(weight: number, fadeTime?: number): void;
  Play(fadeTime?: number, weight?: number, speed?: number): void;
  Stop(fadeTime?: number): void;
  AdjustWeight(weight: number, fadeTime?: number): void;
  AdjustSpeed(speed: number, fadeTime?: number): void;
  IsPlaying(): boolean;
}

interface AnimationTrackPlayerConstructor {
  readonly ClassName: 'AnimationTrackPlayer';
  new (
    animationTarget?: Mountable<Instance>,
    animationId?: string | number
  ): AnimationTrackPlayer;
}

export const AnimationTrackPlayer: AnimationTrackPlayerConstructor;
