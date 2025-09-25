import { ServiceBag } from '@quenty/servicebag';

export interface SoundGroupServiceClient {
  readonly ServiceName: 'SoundGroupServiceClient';
  Init(serviceBag: ServiceBag): void;
  Destroy(): void;
}
