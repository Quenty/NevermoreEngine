import { ServiceBag } from '@quenty/servicebag';
import { CooldownBase } from './CooldownBase';
import { Binder } from '@quenty/binder';

interface CooldownShared extends CooldownBase {}

interface CooldownSharedConstructor {
  readonly ClassName: 'CooldownShared';
  new (numberValue: NumberValue, serviceBag: ServiceBag): CooldownShared;
}

export const CooldownShared: Binder<CooldownShared>;
