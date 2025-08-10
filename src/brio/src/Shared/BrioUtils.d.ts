import { Brio } from './Brio';

export const clone: <T extends unknown[]>(brio: Brio<T>) => Brio<T>;
export const aliveOnly: <T extends unknown[]>(
  brios: Array<Brio<T>>
) => Array<Brio<T>>;
export const firstAlive: <T extends unknown[]>(
  brios: Array<Brio<T>>
) => Brio<T> | undefined;
export const flatten: <K extends unknown, T extends unknown[]>(
  brioTable: Map<K, Brio<T> | T>
) => Brio<[Map<K, T>]>;
export const first: <T extends unknown[], U extends unknown[]>(
  brios: Array<Brio<T>>,
  ...values: U
) => Brio<U>;
export const withOtherValues: <T extends unknown[], U extends unknown[]>(
  brio: Brio<T>,
  ...values: U
) => Brio<U>;
export const extend: <T extends unknown[]>(
  brio: Brio<unknown[]>,
  ...values: T
) => Brio<T>;
export const prepend: <T extends unknown[]>(
  brio: Brio<unknown[]>,
  ...values: T
) => Brio<T>;
export const merge: <T extends unknown[], U extends unknown[]>(
  brio: Brio<T>,
  otherBrio: Brio<U>
) => Brio<[...T, ...U]>;
