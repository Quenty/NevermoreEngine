import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface SecretsService {
  readonly ServiceName: 'SecretsService';
  Init(serviceBag: ServiceBag): void;
  SetPublicKeySeed(seed: number): void;
  Start(): void;
  PromiseSecret(secretKey: string): Promise<string>;
  PromiseAllSecrets(): Promise<string[]>;
  ObserveSecret(secretKey: string): Observable<string>;
  DeleteSecret(secretKey: string): Promise;
  StoreSecret(secretKey: string, value: string): void;
  ClearAllSecrets(): Promise;
  PromiseSecretKeyNamesList(): Promise<string[]>;
  Destroy(): void;
}
