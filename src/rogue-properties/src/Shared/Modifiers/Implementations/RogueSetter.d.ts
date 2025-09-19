import { ServiceBag } from '@quenty/servicebag';
import { RogueModifierBase } from './RogueModifierBase';
import { Binder } from '@quenty/binder';

export interface RogueSetter extends RogueModifierBase {}

export interface RogueSetterConstructor {
  readonly ClassName: 'RogueSetter';
  new (obj: ValueBase, serviceBag: ServiceBag): RogueSetter;
}

export const RogueSetter: Binder<RogueSetterConstructor>;
