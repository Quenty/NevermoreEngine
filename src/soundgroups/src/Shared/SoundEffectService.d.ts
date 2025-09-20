import { ServiceBag } from '@quenty/servicebag';
import { SoundEffectApplier } from './Effects/SoundEffectsList';

export interface SoundEffectService {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  RegisterSFX(sound: Sound, soundGroupPath?: string): void;
  GetOrCreateSoundGroup(soundGroupPath: string): SoundGroup;
  GetSoundGroup(soundGroupPath: string): SoundGroup;
  PushEffect(soundGroupPath: string, effect: SoundEffectApplier): () => void;
  ApplyEffects(
    soundGroupPath: string,
    instance: Sound | SoundGroup
  ): () => void;
  Destroy(): void;
}
