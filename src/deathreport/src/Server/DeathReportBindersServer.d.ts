import { BinderProvider } from '@quenty/binder';
import { PlayerDeathTracker } from './Stats/PlayerDeathTracker';
import { PlayerKillTracker } from './Stats/PlayerKillTracker';
import { TeamKillTracker } from './Stats/TeamKillTracker';

export const DeathReportBindersServer: BinderProvider<{
  TeamKillTracker: TeamKillTracker;
  PlayerKillTracker: PlayerKillTracker;
  PlayerDeathTracker: PlayerDeathTracker;
}>;
