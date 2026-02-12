import { ServiceBag } from '@quenty/servicebag';

export interface HideService {
  readonly ServiceName: 'HideService';
  Init(serviceBag: ServiceBag): void;
}
