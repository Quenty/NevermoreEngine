import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { DataStore } from './DataStore';

export interface GameDataStoreService {
  readonly ServiceName: 'GameDataStoreService';
  Init(serviceBag: ServiceBag): void;
  PromiseDataStore(): Promise<DataStore<unknown>>;
  Destroy(): void;
}
