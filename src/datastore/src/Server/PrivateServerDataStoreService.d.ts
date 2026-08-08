import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { DataStore } from './DataStore';

export interface PrivateServerDataStoreService {
  readonly ServiceName: 'PrivateServerDataStoreService';
  Init(serviceBag: ServiceBag): void;
  PromiseDataStore(): Promise<DataStore<unknown>>;
  SetCustomKey(customKey: string): void;
  Destroy(): void;
}
