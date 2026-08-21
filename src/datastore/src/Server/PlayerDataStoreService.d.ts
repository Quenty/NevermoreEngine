import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { DataStore } from './DataStore';
import { PlayerDataStoreManager } from './PlayerDataStoreManager';

export interface PlayerDataStoreService {
  readonly ServiceName: 'PlayerDataStoreService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  SetDataStoreName(dataStoreName: string): void;
  SetDataStoreScope(dataStoreScope: string): void;
  PromiseDataStore(): Promise<DataStore<unknown>>;
  PromiseAddRemovingCallback(callback: () => Promise<unknown> | void): Promise;
  PromiseManager(): Promise<PlayerDataStoreManager>;
  Destroy(): void;
}
