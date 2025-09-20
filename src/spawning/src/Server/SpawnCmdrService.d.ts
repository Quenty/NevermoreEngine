import { ServiceBag } from '@quenty/servicebag';

export interface SpawnCmdrService {
  readonly ServiceName: 'SpawnCmdrService';
  Init(serviceBag: ServiceBag): void;
}
