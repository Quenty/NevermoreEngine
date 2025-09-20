import { ServiceBag } from '@quenty/servicebag';

export interface IdleService {
  readonly ServiceName: 'IdleService';
  Init(serviceBag: ServiceBag): void;
}
