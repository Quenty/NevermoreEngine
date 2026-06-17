export namespace AnimationUtils {
  function playAnimation(
    target: Animator | Player | Model | AnimationController,
    id: string | number,
    fadeTime?: number,
    weight?: number,
    speed?: number,
    priority?: Enum.AnimationPriority
  ): AnimationTrack | undefined;
  function stopAnimation(
    target: Animator | Player | Model | AnimationController,
    id: string | number,
    fadeTime?: number
  ): AnimationTrack | undefined;
  function getOrCreateAnimationTrack(
    target: Animator | Player | Model | AnimationController,
    id: string | number,
    priority?: Enum.AnimationPriority
  ): AnimationTrack | undefined;
  function getOrCreateAnimationFromIdInAnimator(
    animator: Animator,
    id: string | number
  ): Animation;
  function findAnimationTrack(
    target: Animator | Player | Model | AnimationController,
    id: string | number
  ): AnimationTrack | undefined;
  function findAnimationTrackInAnimator(
    animator: Animator,
    id: string | number
  ): AnimationTrack | undefined;
  function getOrCreateAnimator(
    target: Animator | Player | Model | Humanoid | AnimationController
  ): Animator | undefined;
  function getAnimationName(animationId: string): string;
  function createAnimationFromId(id: string | number): Animation;
}
