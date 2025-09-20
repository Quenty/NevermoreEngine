import { ServiceBag } from '@quenty/servicebag';

export interface HideService {
  Init(serviceBag: ServiceBag): void;
}
