import { ServiceBag } from '@quenty/servicebag';

export interface SoundGroupServiceClient {
  Init(serviceBag: ServiceBag): void;
  Destroy(): void;
}
