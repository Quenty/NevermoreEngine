import { ServiceBag } from '@quenty/servicebag';
import { CooldownBase } from '../../Shared/Binders/CooldownBase';
import { Binder } from '@quenty/binder';

interface CooldownClient extends CooldownBase {}

interface CooldownClientConstructor {
  readonly ClassName: 'CooldownClient';
  new (numberValue: NumberValue, serviceBag: ServiceBag): CooldownClient;
}

export const CooldownClient: Binder<CooldownClient>;
