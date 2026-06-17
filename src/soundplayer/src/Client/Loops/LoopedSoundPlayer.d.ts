import { SoundIdLike } from '@quenty/sounds';
import { SpringTransitionModel } from '@quenty/transitionmodel';
import { SoundLoopSchedule } from '../Schedule/SoundLoopScheduleUtils';
import { Promise } from '@quenty/promise';

interface LoopedSoundPlayer extends SpringTransitionModel<number> {
  SetCrossFadeTime(crossFadeTime: number): void;
  SetVolumeMultiplier(volume: number): void;
  SetSoundGroup(soundGroup: SoundGroup | undefined): void;
  SetBPM(bpm: number | undefined): void;
  SetSoundParent(parent: Instance | undefined): void;
  Swap(
    soundId: SoundIdLike | undefined,
    loopSchedule?: SoundLoopSchedule
  ): void;
  SetDoSyncSoundPlayback(doSyncSoundPlayback: boolean): void;
  SwapToSamples(
    soundIdList: SoundIdLike[],
    loopSchedule?: SoundLoopSchedule
  ): void;
  SwapToChoice(
    soundIdList: SoundIdLike[],
    loopSchedule?: SoundLoopSchedule
  ): void;
  PlayOnce(
    soundId: SoundIdLike | undefined,
    loopSchedule?: SoundLoopSchedule
  ): void;
  SwapOnLoop(
    soundId: SoundIdLike | undefined,
    loopSchedule?: SoundLoopSchedule
  ): void;
  PlayOnceOnLoop(
    soundId: SoundIdLike | undefined,
    loopSchedule?: SoundLoopSchedule
  ): void;
  StopAfterLoop(): void;
  PromiseLoopDone(): Promise;
  PromiseSustain(): Promise;
  GetSound(): Sound | undefined;
}

interface LoopedSoundPlayerConstructor {
  readonly ClassName: 'LoopedSoundPlayer';
  new (soundId?: SoundIdLike, soundParent?: Instance): LoopedSoundPlayer;
}

export const LoopedSoundPlayer: LoopedSoundPlayerConstructor;
