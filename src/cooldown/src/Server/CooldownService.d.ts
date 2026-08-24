import { ServiceBag } from '@quenty/servicebag';

export interface CooldownService {
  readonly ServiceName: 'CooldownService';
  Init(serviceBag: ServiceBag): void;
}
