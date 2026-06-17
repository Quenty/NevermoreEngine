type DictionaryLike = Record<any, unknown> | Map<unknown, unknown>;
type TableLike = DictionaryLike | unknown[];

type InvertDictionary<T extends Record<PropertyKey, PropertyKey>> = {
  [P in keyof T as T[P]]: P;
};

export namespace Table {
  function append<T>(target: T[], source: T[]): T[];
  function merge<T1 extends DictionaryLike, T2 extends DictionaryLike>(
    orig: T1,
    other: T2
  ): T1 & T2;
  function reverse<T>(array: T[]): T[];
  function values<T extends DictionaryLike>(
    source: T
  ): T extends Map<unknown, infer V> ? V[] : T[keyof T][];
  function keys<T extends DictionaryLike>(
    source: T
  ): T extends Map<infer K, unknown> ? K[] : (keyof T)[];
  const mergeLists: typeof merge;
  function swapKeyValue<T extends DictionaryLike>(
    source: T
  ): T extends Map<infer K, infer V>
    ? Map<V, K>
    : T extends Record<PropertyKey, PropertyKey>
    ? InvertDictionary<T>
    : never;
  function toList<T extends DictionaryLike>(
    source: T
  ): T extends Map<unknown, infer V> ? V[] : T[keyof T][];
  function count(table: DictionaryLike | unknown[]): number;
  function copy<T extends DictionaryLike | unknown[]>(table: T): T;
  function deepCopy<T extends TableLike>(
    table: T,
    deepCopyContext?: TableLike
  ): T;
  function deepOverwrite<T extends DictionaryLike, U extends DictionaryLike>(
    target: T,
    source: U
  ): T & U;
  function getIndex<T>(haystack: T[], needle: T): number | undefined;
  function stringify(
    table: DictionaryLike | unknown[],
    indent?: number,
    output?: string
  ): string;
  function contains<T>(table: T[], value: T): boolean;
  function overwrite<T extends DictionaryLike, U extends DictionaryLike>(
    target: T,
    source: U
  ): T & U;
  function deepEquivalent<T extends DictionaryLike, U extends DictionaryLike>(
    a: T,
    b: U
  ): boolean;
  function take<T>(array: T[], count: number): T[];
  function readonly<T extends DictionaryLike | unknown[]>(
    table: T
  ): Readonly<T>;
  function errorOnNilIndex<T extends DictionaryLike | unknown[]>(target: T): T;
  function deepReadonly<T extends DictionaryLike | unknown[]>(
    target: T
  ): Readonly<T>;
}
