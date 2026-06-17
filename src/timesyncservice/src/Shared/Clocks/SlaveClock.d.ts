import { BaseObject } from '@quenty/baseobject';
import { BaseClock } from './BaseClock';

interface SlaveClock extends BaseObject, BaseClock {
  TickToSyncedTime(syncedTime: number): number;
}

interface SlaveClockConstructor {
  readonly ClassName: 'SlaveClock';
  new (remoteEvent: RemoteEvent, remoteFunction: RemoteFunction): SlaveClock;
}

export const SlaveClock: SlaveClockConstructor;
