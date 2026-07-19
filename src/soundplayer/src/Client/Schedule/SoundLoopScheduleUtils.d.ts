export interface SoundLoopSchedule {
  playOnNextLoop?: boolean;
  maxLoops?: number;
  initialDelay?: number | NumberRange;
  loopDelay?: number | NumberRange;
  maxInitialWaitTimeForNextLoop?: number | NumberRange;
}

export namespace SoundLoopScheduleUtils {
  function schedule(
    loopedSchedule: SoundLoopSchedule
  ): Readonly<SoundLoopSchedule>;
  function onNextLoop(loopedSchedule: SoundLoopSchedule): SoundLoopSchedule;
  function maxLoops(
    maxLoops: number,
    loopedSchedule: SoundLoopSchedule
  ): SoundLoopSchedule;
  //   reserved keyword
  //   function default(): SoundLoopSchedule;
  function isWaitTimeSeconds(value: unknown): value is number | NumberRange;
  function isLoopedSchedule(value: unknown): value is SoundLoopSchedule;
  function getWaitTimeSeconds(waitTime: number | NumberRange): number;
}
