import { ServiceBag } from '@quenty/servicebag';
import { CooldownBase } from '../../Shared/Binders/CooldownBase';
import { Binder } from '@quenty/binder';

interface Cooldown extends CooldownBase {}

interface CooldownConstructor {
  readonly ClassName: 'Cooldown';
  new (numberValue: NumberValue, serviceBag: ServiceBag): Cooldown;
}

export const Cooldown: Binder<Cooldown>;
