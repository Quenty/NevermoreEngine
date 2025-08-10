import { Brio } from "./Brio";

export declare const clone: <T extends unknown[]>(brio: Brio<T>) => Brio<T>;
export declare const aliveOnly: <T extends unknown[]>(brios: Array<Brio<T>>) => Array<Brio<T>>;
export declare const firstAlive: <T extends unknown[]>(brios: Array<Brio<T>>) => Brio<T> | undefined;
export declare const flatten: <K extends unknown, T extends unknown[]>(brioTable: Map<K, Brio<T> | T>) => Brio<[Map<K, T>]>;
export declare const first: <T extends unknown[], U extends unknown[]>(brios: Array<Brio<T>>, ...values: U) => Brio<U>;
export declare const withOtherValues: <T extends unknown[], U extends unknown[]>(brio: Brio<T>, ...values: U) => Brio<U>;
export declare const extend: <T extends unknown[]>(brio: Brio<unknown[]>, ...values: T) => Brio<T>;
export declare const prepend: <T extends unknown[]>(brio: Brio<unknown[]>, ...values: T) => Brio<T>;
export declare const merge: <T extends unknown[], U extends unknown[]>(brio: Brio<T>, otherBrio: Brio<U>) => Brio<[...T, ...U]>;