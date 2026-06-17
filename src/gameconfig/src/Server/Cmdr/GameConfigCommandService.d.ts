import { ServiceBag } from '@quenty/servicebag';

export interface GameConfigCommandService {
  readonly ServiceName: 'GameConfigCommandService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
}
