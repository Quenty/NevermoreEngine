import { Observable } from '@quenty/rx';
import { BaseClock } from './Clocks/BaseClock';

export interface TimeSyncService {
  Init(): void;
  IsSynced(): boolean;
  WaitForSyncedClock(): BaseClock;
  GetSyncedClock(): BaseClock | undefined;
  PromiseSyncedClock(): Promise<BaseClock>;
  ObserveSyncedClock(): Observable<BaseClock>;
  Destroy(): void;
}
