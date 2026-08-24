import { Signal } from '@quenty/signal';
import { DataStoreStage } from './Modules/DataStoreStage';
import { RobloxDataStore } from './Utility/DataStorePromises';
import { Promise } from '@quenty/promise';

interface DataStore<T> extends DataStoreStage<T> {
  Saving: Signal<Promise>;
  SetDoDebugWriting(debugWriting: boolean): void;
  GetFullPath(): string;
  SetAutoSaveTimeSeconds(autoSaveTimeSeconds: number | undefined): void;
  SetSyncOnSave(syncEnabled: boolean): void;
  DidLoadFail(): boolean;
  PromiseLoadSuccessful(): Promise<boolean>;
  Save(): Promise;
  Sync(): Promise;
  SetUserIdList(userIdList: number[] | undefined): void;
  GetUserIdList(): number[] | undefined;
}

interface DataStoreConstructor {
  readonly ClassName: 'DataStore';
  new <T = unknown>(
    robloxDataStore: RobloxDataStore,
    key: string
  ): DataStore<T>;
}

export const DataStore: DataStoreConstructor;
