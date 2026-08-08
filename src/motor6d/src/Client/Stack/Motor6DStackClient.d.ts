import { ServiceBag } from '@quenty/servicebag';
import { Binder } from '@quenty/binder';
import { Motor6DStackBase } from '../../Shared/Stack/Motor6DStackBase';

interface Motor6DStackClient extends Motor6DStackBase {}

interface Motor6DStackClientConstructor {
  readonly ClassName: 'Motor6DStackClient';
  new (motor6D: Motor6D, serviceBag: ServiceBag): Motor6DStackClient;
}

export const Motor6DStackClient: Binder<Motor6DStackClient>;
