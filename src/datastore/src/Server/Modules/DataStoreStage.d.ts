import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { DataStoreWriter } from './DataStoreWriter';
import { Maid } from '@quenty/maid';

export type DataStoreStageKey = string | number;

export type DataStoreCallback = () => Promise | undefined;

interface DataStoreStage<T> extends BaseObject {
  Changed: Signal<unknown>;
  DataStored: Signal<unknown>;
  Store(key: string, value: T): void;
  Load(key: DataStoreStageKey): Promise<T | undefined>;
  Load(key: DataStoreStageKey, defaultValue: T): Promise<T>;
  LoadAll(): Promise<Record<DataStoreStageKey, T>>;
  GetSubStore<V = unknown>(key: DataStoreStageKey): DataStoreStage<V>;
  Delete(key: DataStoreStageKey): void;
  Wipe(): void;
  Observe(key?: DataStoreStageKey, defaultValue?: T): Observable<T | undefined>;
  AddSavingCallback(callback: DataStoreCallback): () => void;
  RemoveSavingCallback(callback: DataStoreCallback): void;
  GetTopLevelDataStoredSignal(): Signal;
  GetFullPath(): string;
  PromiseKeyList(): Promise<string[]>;
  PromiseKeySet(): Promise<Map<string, true>>;
  MergeDiffSnapshot(diffSnapshot: T): void;
  MarkDataAsSaved(parentWriter: DataStoreWriter): void;
  PromiseViewUpToDate(): Promise<T>;
  Overwrite(data: T): void;
  OverwriteMerge(data: T): void;
  StoreOnValueChange(key: DataStoreStageKey, valueObj: ValueBase): Maid;
  HasWritableData(): boolean;
  GetNewWriter(): DataStoreWriter;
  PromiseInvokeSavingCallbacks(): Promise;
}

interface DataStoreStageConstructor {
  readonly ClassName: 'DataStoreStage';
  new <T = unknown>(
    loadName: DataStoreStageKey,
    loadParent?: DataStoreStage<unknown>
  ): DataStoreStage<T>;
}

export const DataStoreStage: DataStoreStageConstructor;
