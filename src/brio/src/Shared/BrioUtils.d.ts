import { Brio } from './Brio';

type ToTuple<T> = T extends [unknown, ...unknown[]] ? T : [T];

type BrioInnerOrTuple<B> = B extends Brio<infer R>
  ? R extends unknown[]
    ? R
    : [R]
  : never;

type FlattenTuples<T extends unknown[]> = T extends [infer Head, ...infer Tail]
  ? Head extends unknown[]
    ? [...Head, ...FlattenTuples<Tail>]
    : [Head, ...FlattenTuples<Tail>]
  : [];

export namespace BrioUtils {
  function clone<T>(brio: Brio<T>): Brio<T>;
  function aliveOnly<T>(brios: Array<Brio<T>>): Array<Brio<T>>;
  function firstAlive<T>(brios: Array<Brio<T>>): Brio<T> | undefined;
  function flatten<K extends unknown, T>(
    brioTable: Map<K, Brio<T> | T>
  ): Brio<Map<K, T>>;
  function first<T, U>(brios: Array<Brio<T>>, ...values: ToTuple<U>): Brio<U>;
  function withOtherValues<T, U>(brio: Brio<T>, ...values: ToTuple<U>): Brio<U>;
  function extend<T, U extends Brio<unknown>[]>(
    brio: Brio<T>,
    ...values: U
  ): Brio<
    LuaTuple<
      [
        ...ToTuple<T>,
        ...FlattenTuples<{ [K in keyof U]: BrioInnerOrTuple<U[K]> }>
      ]
    >
  >;
  function prepend<T>(brio: Brio<unknown[]>, ...values: ToTuple<T>): Brio<T>;
  function merge<T, U>(
    brio: Brio<T>,
    otherBrio: Brio<U>
  ): Brio<LuaTuple<[...ToTuple<T>, ...ToTuple<U>]>>;
}

export {};
