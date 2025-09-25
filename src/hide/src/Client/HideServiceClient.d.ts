import { ServiceBag } from '@quenty/servicebag';

export interface HideServiceClient {
  readonly ServiceName: 'HideServiceClient';
  Init(serviceBag: ServiceBag): void;
}
