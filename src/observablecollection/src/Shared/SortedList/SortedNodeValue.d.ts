type CompareFunction<T> = (a: T, b: T) => number;

interface SortedNodeValue<T> extends Iterable<T> {
  GetValue(): T;
  __eq(other: SortedNodeValue<T>): boolean;
  __lt(other: SortedNodeValue<T>): boolean;
  __gt(other: SortedNodeValue<T>): boolean;
}

interface SortedNodeValueConstructor {
  readonly ClassName: 'SortedNodeValue';
  new (): SortedNodeValue<never>;
  new <T>(value: T, compare: CompareFunction<T>): SortedNodeValue<T>;

  isSortedNodeValue(value: any): value is SortedNodeValue<any>;
}

export const SortedNodeValue: SortedNodeValueConstructor;
