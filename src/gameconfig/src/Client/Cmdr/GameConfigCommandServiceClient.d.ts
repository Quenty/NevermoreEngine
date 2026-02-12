import { ServiceBag } from '@quenty/servicebag';

export interface GameConfigCommandServiceClient {
  readonly ServiceName: 'GameConfigCommandServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  Destroy(): void;
}
