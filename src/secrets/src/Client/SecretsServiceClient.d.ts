import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';

export interface SecretsServiceClient {
  readonly ServiceName: 'SecretsServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  PromiseSecretKeyNamesList(): Promise<string[]>;
  Destroy(): void;
}
