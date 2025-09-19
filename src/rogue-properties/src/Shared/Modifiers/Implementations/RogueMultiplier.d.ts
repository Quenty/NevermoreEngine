import { ServiceBag } from '@quenty/servicebag';
import { RogueModifierBase } from './RogueModifierBase';
import { Binder } from '@quenty/binder';

export interface RogueMultiplier extends RogueModifierBase {}

export interface RogueMultiplierConstructor {
  readonly ClassName: 'RogueMultiplier';
  new (obj: ValueBase, serviceBag: ServiceBag): RogueMultiplier;
}

export const RogueMultiplier: Binder<RogueMultiplierConstructor>;
