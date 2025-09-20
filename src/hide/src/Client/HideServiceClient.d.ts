import { ServiceBag } from '@quenty/servicebag';

export interface HideServiceClient {
  Init(serviceBag: ServiceBag): void;
}
