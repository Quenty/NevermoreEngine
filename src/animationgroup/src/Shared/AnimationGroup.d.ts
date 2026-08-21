import { BaseObject } from '@quenty/baseobject';
import { WeightedTrack } from './AnimationGroupUtils';

interface AnimationGroup extends BaseObject {
  Play(transitionTime?: number): void;
  SetWeightedTracks(
    weightedTracks: WeightedTrack[],
    transitionTime?: number
  ): void;
  Stop(transitionTime?: number): void;
}

interface AnimationGroupConstructor {
  readonly ClassName: 'AnimationGroup';
  new (weightedTracks?: WeightedTrack[]): AnimationGroup;
}

export const AnimationGroup: AnimationGroupConstructor;
