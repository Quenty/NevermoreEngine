export interface WeightedAnimation {
  animationId: string;
  weight: number;
}

export interface WeightedTrack {
  track: AnimationTrack;
  weight: number;
}

export namespace AnimationGroupUtils {
  function createdWeightedTracks(
    animatorOrHumanoid: Animator | Humanoid,
    weightedAnimationList: WeightedAnimation[]
  ): WeightedTrack[];
  function createdWeightedAnimation(
    animationId: string,
    weight: number
  ): WeightedAnimation;
  function createdWeightedTrack(
    track: AnimationTrack,
    weight: number
  ): WeightedTrack;
  function selectFromWeightedTracks(
    weightedTracks: WeightedTrack[]
  ): WeightedTrack | undefined;
}
