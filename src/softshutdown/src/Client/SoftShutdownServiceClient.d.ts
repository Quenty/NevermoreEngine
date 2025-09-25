import { ServiceBag } from '@quenty/servicebag';

export interface SoftShutdownServiceClient {
  readonly ServiceName: 'SoftShutdownServiceClient';
  Init(serviceBag: ServiceBag): void;
  Destroy(): void;
}
