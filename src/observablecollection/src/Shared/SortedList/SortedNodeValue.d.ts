import { CompareFunction } from './SortedNode';

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

  isSortedNodeValue(value: unknown): value is SortedNodeValue<unknown>;
}

export const SortedNodeValue: SortedNodeValueConstructor;
