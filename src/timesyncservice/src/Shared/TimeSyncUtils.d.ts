import { Promise } from '@quenty/promise';
import { SlaveClock } from './Clocks/SlaveClock';
import { MasterClock } from './Clocks/MasterClock';

export namespace TimeSyncUtils {
  function promiseClockSynced(
    clock: MasterClock | SlaveClock
  ): Promise<MasterClock | SlaveClock>;
}
