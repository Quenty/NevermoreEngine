type Set<T> = T extends PropertyKey ? Record<T, true> : Map<T, true>;

type GetSetType<T extends Set<unknown>> = T extends Set<infer A> ? A : never;

export namespace Set {
  function union<T extends Set<unknown>, U extends Set<unknown>>(
    set: T,
    otherSet: U
  ): Set<GetSetType<T> & GetSetType<U>>;
  function unionUpdate<T extends Set<unknown>, U extends Set<unknown>>(
    set: T,
    otherSet: U
  ): Set<GetSetType<T> & GetSetType<U>>;
  function intersection<T extends Set<unknown>, U extends Set<unknown>>(
    set: T,
    otherSet: U
  ): Set<GetSetType<T> & GetSetType<U>>;
  function copy<T extends Set<unknown>>(set: T): T;
  function count(set: Set<unknown>): number;
  function fromKeys<
    T extends Map<unknown, unknown> | Record<PropertyKey, unknown>
  >(
    tab: T
  ): T extends Map<infer K, unknown>
    ? Set<K>
    : T extends Record<infer K, unknown>
    ? Set<K>
    : never;
  function fromTableValue<
    T extends Map<unknown, unknown> | Record<PropertyKey, unknown>
  >(
    tab: T
  ): T extends Map<unknown, infer V>
    ? Set<V>
    : T extends Record<PropertyKey, infer V>
    ? Set<V>
    : never;
  const fromList: typeof fromTableValue;
  function toList<T>(set: Set<T>): T[];
  function differenceUpdate<T>(set: Set<T>, otherSet: Set<T>): void;
  function difference<T>(set: Set<T>, otherSet: Set<T>): Set<T>;
}
