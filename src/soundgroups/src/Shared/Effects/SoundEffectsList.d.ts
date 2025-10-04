import { MaidTask } from '@quenty/maid';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

export type SoundEffectApplier = (
  instance: SoundGroup | Sound
) => MaidTask | undefined;

interface SoundEffectsList {
  IsActiveChanged: Signal<boolean>;
  ObserveHasEffects(): Observable<boolean>;
  IsActive(): boolean;
  PushEffect(effect: SoundEffectApplier): () => void;
  ApplyEffects(instance: SoundGroup | Sound): () => void;
  HasEffects(): boolean;
}

interface SoundEffectsListConstructor {
  readonly ClassName: 'SoundEffectsList';
  new (): SoundEffectsList;
}

export const SoundEffectsList: SoundEffectsListConstructor;
