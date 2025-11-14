import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';
import { ClockFunction } from '@quenty/timesyncservice';
import { Mountable } from '@quenty/valueobject';

interface CooldownModel extends BaseObject {
  Done: Signal;
  SetClock(clock: Mountable<ClockFunction>): void;
  SetStartTime(startTime: Mountable<number>): void;
  SetLength(length: Mountable<number>): void;
  GetStartTime(): number;
  GetTimeRemaining(): number;
  GetTimePassed(): number;
  GetEndTime(): number;
  GetLength(): number;
}

interface CooldownModelConstructor {
  readonly ClassName: 'CooldownModel';
  new (): CooldownModel;

  isCooldownModel: (value: unknown) => value is CooldownModel;
}

export const CooldownModel: CooldownModelConstructor;
