import { BaseObject } from '@quenty/baseobject';
import { BaseClock } from './BaseClock';

interface MasterClock extends BaseObject, BaseClock {}

interface MasterClockConstructor {
  readonly ClassName: 'MasterClock';
  new (remoteEvent: RemoteEvent, remoteFunction: RemoteFunction): MasterClock;
}

export const MasterClock: MasterClockConstructor;
