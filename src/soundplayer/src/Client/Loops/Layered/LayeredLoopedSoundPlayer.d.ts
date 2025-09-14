import { SoundIdLike } from '@quenty/sounds';
import { SpringTransitionModel } from '@quenty/transitionmodel';
import { Mountable } from '@quenty/valueobject';
import { SoundLoopSchedule } from '../../Schedule/SoundLoopScheduleUtils';

interface LayeredLoopedSoundPlayer extends SpringTransitionModel<number> {
  SetDefaultCrossFadeTime(crossFadeTime: Mountable<number>): void;
  SetVolumeMultiplier(volumeMultiplier: Mountable<number>): void;
  SetBPM(bpm: Mountable<number | undefined>): void;
  SetSoundParent(soundParent: Instance | undefined): void;
  SetSoundGroup(soundGroup: SoundGroup | undefined): void;
  Swap(
    layerId: string,
    soundId: SoundIdLike | undefined,
    scheduleOptions?: SoundLoopSchedule
  ): void;
}

interface LayeredLoopedSoundPlayerConstructor {
  readonly ClassName: 'LayeredLoopedSoundPlayer';
  new (soundParent?: Instance): LayeredLoopedSoundPlayer;
}

export const LayeredLoopedSoundPlayer: LayeredLoopedSoundPlayerConstructor;
