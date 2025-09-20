import { BaseObject } from '@quenty/baseobject';
import { SoundEffectApplier } from './SoundEffectsList';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

interface SoundEffectsRegistry extends BaseObject {
  PushEffect(soundGroupPath: string, effect: SoundEffectApplier): () => void;
  ApplyEffects(
    soundGroupPath: string,
    instance: SoundGroup | Sound
  ): () => void;
  ObserveActiveEffectsPathBrios(): Observable<Brio<string>>;
}

interface SoundEffectsRegistryConstructor {
  readonly ClassName: 'SoundEffectsRegistry';
  new (): SoundEffectsRegistry;
}

export const SoundEffectsRegistry: SoundEffectsRegistryConstructor;
