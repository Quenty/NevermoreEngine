import { ServiceBag } from '@quenty/servicebag';

export interface CooldownServiceClient {
  readonly ServiceName: 'CooldownServiceClient';
  Init(serviceBag: ServiceBag): void;
}
