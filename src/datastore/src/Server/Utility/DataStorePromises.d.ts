import { Promise } from '@quenty/promise';

export type RobloxDataStore = DataStore;

export namespace DataStorePromises {
  function promiseDataStore(name: string, scope: string): Promise<DataStore>;
  function promiseOrderedDataStore(
    name: string,
    scope: string
  ): Promise<OrderedDataStore>;
  function getAsync(
    robloxDataStore: DataStore,
    key: string
  ): Promise<[value: unknown, dataStoreKeyInfo: DataStoreKeyInfo]>;
  function updateAsync<O, R>(
    robloxDataStore: DataStore,
    key: string,
    updateFunc: (
      oldValue: O | undefined,
      keyInfo: DataStoreKeyInfo | undefined
    ) => LuaTuple<[newValue: R | undefined, userIds?: number[], metadata?: {}]>
  ): Promise<[newValue: R | undefined, keyInfo: DataStoreKeyInfo]>;
  function setAsync(
    robloxDataStore: DataStore,
    key: string,
    value: unknown,
    userIds?: number[]
  ): Promise<true>;
  function promiseIncrementAsync(
    robloxDataStore: DataStore,
    key: string,
    delta: number
  ): Promise<true>;
  function removeAsync(robloxDataStore: DataStore, key: string): Promise<true>;
  function promiseSortedPagesAsync(
    orderedDataStore: OrderedDataStore,
    ascending: boolean,
    pageSize: number,
    minValue?: number,
    maxValue?: number
  ): Promise<DataStorePages>;
  function promiseOrderedEntries(
    orderedDataStore: OrderedDataStore,
    ascending: boolean,
    pageSize: number,
    entries: number,
    minValue?: number,
    maxValue?: number
  ): Promise<DataStorePages extends Pages<infer T> ? T[] : never>;
}
