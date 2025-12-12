import { ValueObject } from '../../../valueobject';

type EquippedTracker = {
  Player: ValueObject<Player | undefined>;
  Destroy(): void;
};

interface EquippedTrackerConstructor {
  readonly ClassName: 'EquippedTracker';
  new (tool: Tool): EquippedTracker;
}

export const EquippedTracker: EquippedTrackerConstructor;
