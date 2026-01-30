import { ServiceBag } from '@quenty/servicebag';

export interface SecretsCommandService {
  readonly ServiceName: 'SecretsCommandService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  Destroy(): void;
}
