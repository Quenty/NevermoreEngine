import { Observable } from '@quenty/rx';

export type ClockFunction = () => number;

export interface BaseClock {
  GetTime(): number;
  GetPing(): number;
  IsSynced(): boolean;
  ObservePing(): Observable<number>;
  GetClockFunction(): ClockFunction;
}

export const BaseClock: {};
