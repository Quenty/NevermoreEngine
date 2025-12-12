import { BinderProvider } from '@quenty/binder';
import { PlayerDeathTrackerClient } from './Stats/PlayerDeathTrackerClient';
import { PlayerKillTrackerClient } from './Stats/PlayerKillTrackerClient';
import { TeamKillTrackerClient } from './Stats/TeamKillTrackerClient';

export const DeathReportBindersClient: BinderProvider<{
  TeamKillTracker: TeamKillTrackerClient;
  PlayerKillTracker: PlayerKillTrackerClient;
  PlayerDeathTracker: PlayerDeathTrackerClient;
}>;
