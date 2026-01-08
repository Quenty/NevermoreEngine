import { ServiceBag } from '@quenty/servicebag';

export interface SoftShutdownService {
  readonly ServiceName: 'SoftShutdownService';
  Init(serviceBag: ServiceBag): void;
  Destroy(): void;
}
