import { ServiceBag } from '@quenty/servicebag';

export interface SpawnServiceClient {
  Init(serviceBag: ServiceBag): void;
}
