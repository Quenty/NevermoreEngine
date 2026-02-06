import { Promise } from '@quenty/promise';
import { SoundIdLike } from '@quenty/sounds';
import { TimedTransitionModel } from '@quenty/transitionmodel';

interface SimpleLoopedSoundPlayer extends TimedTransitionModel {
  SetSoundGroup(soundGroup: SoundGroup | undefined): void;
  SetVolumeMultiplier(volume: number): void;
  PromiseSustain(): Promise;
  PromiseLoopDone(): Promise;
}

interface SimpleLoopedSoundPlayerConstructor {
  readonly ClassName: 'SimpleLoopedSoundPlayer';
  new (soundId: SoundIdLike): SimpleLoopedSoundPlayer;
}

export const SimpleLoopedSoundPlayer: SimpleLoopedSoundPlayerConstructor;
