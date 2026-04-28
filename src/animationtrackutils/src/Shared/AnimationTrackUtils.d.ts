export namespace AnimationTrackUtils {
  function loadAnimationFromId(
    animatorOrHumanoid: Animator | Humanoid,
    animationId: string
  ): AnimationTrack;
  function setWeightTargetIfNotSet(
    track: AnimationTrack,
    weight: number,
    fadeTime: number
  ): void;
}
