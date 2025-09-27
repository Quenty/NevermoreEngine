import { ServiceBag } from '@quenty/servicebag';
import { Binder } from '@quenty/binder';
import { Motor6DStackBase } from '../../Shared/Stack/Motor6DStackBase';

interface Motor6DStack extends Motor6DStackBase {}

interface Motor6DStackConstructor {
  readonly ClassName: 'Motor6DStack';
  new (motor6D: Motor6D, serviceBag: ServiceBag): Motor6DStack;
}

export const Motor6DStack: Binder<Motor6DStack>;
