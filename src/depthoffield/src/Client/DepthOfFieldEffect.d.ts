import { TransitionModel } from '@quenty/transitionmodel';

interface DepthOfFieldEffect extends TransitionModel {
  SetShowSpeed(speed: number): void;
  SetFocusDistanceTarget(
    focusDistanceTarget: number,
    doNotAnimate?: boolean
  ): void;
  SetFocusRadiusTarget(
    inFocusRadiusTarget: number,
    doNotAnimate?: boolean
  ): void;
  SetNearIntensityTarget(
    nearIntensityTarget: number,
    doNotAnimate?: boolean
  ): void;
  SetFarIntensityTarget(
    farIntensityTarget: number,
    doNotAnimate?: boolean
  ): void;
  GetFocusDistanceTarget(): number;
  GetInFocusRadiusTarget(): number;
  GetNearIntensityTarget(): number;
  GetFarIntensityTarget(): number;
}

interface DepthOfFieldEffectConstructor {
  readonly ClassName: 'DepthOfFieldEffect';
  new (): DepthOfFieldEffect;
}

export const DepthOfFieldEffect: DepthOfFieldEffectConstructor;
