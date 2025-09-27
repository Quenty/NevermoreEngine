import { Brio } from './Brio';

export namespace BrioUtils {
  function clone<T extends unknown[]>(brio: Brio<T>): Brio<T>;
  function aliveOnly<T extends unknown[]>(
    brios: Array<Brio<T>>
  ): Array<Brio<T>>;
  function firstAlive<T extends unknown[]>(
    brios: Array<Brio<T>>
  ): Brio<T> | undefined;
  function flatten<K extends unknown, T extends unknown[]>(
    brioTable: Map<K, Brio<T> | T>
  ): Brio<Map<K, T>>;
  function first<T extends unknown[], U extends unknown[]>(
    brios: Array<Brio<T>>,
    ...values: U
  ): Brio<U>;
  function withOtherValues<T extends unknown[], U extends unknown[]>(
    brio: Brio<T>,
    ...values: U
  ): Brio<U>;
  function extend<T extends unknown[]>(
    brio: Brio<unknown[]>,
    ...values: T
  ): Brio<T>;
  function prepend<T extends unknown[]>(
    brio: Brio<unknown[]>,
    ...values: T
  ): Brio<T>;
  function merge<T extends unknown[], U extends unknown[]>(
    brio: Brio<T>,
    otherBrio: Brio<U>
  ): Brio<[...T, ...U]>;
}
