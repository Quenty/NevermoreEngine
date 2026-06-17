import { Promise } from '@quenty/promise';

export namespace AnimationPromiseUtils {
  function promiseFinished(
    animationTrack: AnimationTrack,
    endMarkerName?: string
  ): Promise;
  function promiseLoaded(animationTrack: AnimationTrack): Promise;
  function promiseKeyframeReached(
    animationTrack: AnimationTrack,
    keyframeName: string
  ): Promise;
}
