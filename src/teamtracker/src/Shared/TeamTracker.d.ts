import { ValueObject } from '@quenty/valueobject';

interface TeamTracker {
  CurrentTeam: ValueObject<Team | undefined>;
  GetPlayer(): Player;
  Destroy(): void;
}

interface TeamTrackerConstructor {
  readonly ClassName: 'TeamTracker';
  new (player: Player): TeamTracker;
}

export const TeamTracker: TeamTrackerConstructor;
