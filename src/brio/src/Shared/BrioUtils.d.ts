import { Brio } from './Brio';

type ToTuple<T> = T extends unknown[] ? T : [T];

export namespace BrioUtils {
  function clone<T>(brio: Brio<T>): Brio<T>;
  function aliveOnly<T>(brios: Array<Brio<T>>): Array<Brio<T>>;
  function firstAlive<T>(brios: Array<Brio<T>>): Brio<T> | undefined;
  function flatten<K extends unknown, T>(
    brioTable: Map<K, Brio<T> | T>
  ): Brio<Map<K, T>>;
  function first<T, U>(brios: Array<Brio<T>>, ...values: ToTuple<U>): Brio<U>;
  function withOtherValues<T, U>(brio: Brio<T>, ...values: ToTuple<U>): Brio<U>;
  function extend<T>(brio: Brio<unknown[]>, ...values: ToTuple<T>): Brio<T>;
  function prepend<T>(brio: Brio<unknown[]>, ...values: ToTuple<T>): Brio<T>;
  function merge<T, U>(
    brio: Brio<T>,
    otherBrio: Brio<U>
  ): Brio<[...ToTuple<T>, ...ToTuple<U>]>;
}

export {};
