export namespace HumanoidAnimatorUtils {
  function getOrCreateAnimator(
    humanoid: Humanoid | AnimationController
  ): Animator;
  function findAnimator(target: Instance): Animator | undefined;
  function stopAnimations(humanoid: Humanoid, fadeTime: number): void;
  function isPlayingAnimationTrack(
    humanoid: Humanoid,
    track: AnimationTrack
  ): boolean;
}
