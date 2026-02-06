import { Observable } from '@quenty/rx';
import { HumanoidTracker } from './HumanoidTracker';
import { Brio } from '@quenty/brio';

export interface HumanoidTrackerService {
  readonly ServiceName: 'HumanoidTrackerService';
  Init(): void;
  GetHumanoidTracker(player?: Player): HumanoidTracker | undefined;
  GetHumanoid(player?: Player): Humanoid | undefined;
  ObserveHumanoid(player?: Player): Observable<Humanoid | undefined>;
  ObserveHumanoidBrio(player?: Player): Observable<Brio<Humanoid>>;
  GetAliveHumanoid(player?: Player): Humanoid | undefined;
  ObserveAliveHumanoid(player?: Player): Observable<Humanoid | undefined>;
  ObserveAliveHumanoidBrio(player?: Player): Observable<Brio<Humanoid>>;
  Destroy(): void;
}
