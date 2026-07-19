import { Promise } from '@quenty/promise';

export namespace MemoryStoreUtils {
  function promiseAdd(
    queue: MemoryStoreQueue,
    value: unknown,
    expirationSeconds: number,
    priority?: number
  ): Promise;
  function promiseRead(
    queue: MemoryStoreQueue,
    count: number,
    allOrNothing: boolean,
    waitTimeout: number
  ): Promise<[values: unknown[], id: string]>;
  function promiseRemove(queue: MemoryStoreQueue, id: string): Promise;
}
