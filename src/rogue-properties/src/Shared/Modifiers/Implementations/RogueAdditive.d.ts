import { ServiceBag } from '@quenty/servicebag';
import { RogueModifierBase } from './RogueModifierBase';
import { Binder } from '@quenty/binder';

export interface RogueAdditive extends RogueModifierBase {}

export interface RogueAdditiveConstructor {
  readonly ClassName: 'RogueAdditive';
  new (obj: ValueBase, serviceBag: ServiceBag): RogueAdditive;
}

export const RogueAdditive: Binder<RogueAdditive>;
