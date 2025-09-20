import { ServiceBag } from '@quenty/servicebag';

export interface IdleService {
  Init(serviceBag: ServiceBag): void;
}
