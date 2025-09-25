import { ServiceBag } from '@quenty/servicebag';

export interface GameProductCmdrService {
  readonly ServiceName: 'GameProductCmdrService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
}
