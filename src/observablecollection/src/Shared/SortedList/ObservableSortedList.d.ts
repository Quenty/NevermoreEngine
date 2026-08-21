import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { Symbol } from '@quenty/symbol';
import { SortedNode } from './SortedNode';

interface ObservableSortedList<T> extends Iterable<T> {
  ItemAdded: Signal<LuaTuple<[item: T, index: number, key: Symbol]>>;
  ItemRemoved: Signal<LuaTuple<[item: T, key: Symbol]>>;
  OrderChanged: Signal;
  CountChanged: Signal<number>;
  Observe(): Observable<T[]>;
  IterateRange(start: number, finish: number): Iterable<T>;
  FindFirstKey(item: T): SortedNode<T> | undefined;
  PrintDebug(): void;
  Contains(item: T): boolean;
  ObserveItemsBrio(): Observable<
    Brio<LuaTuple<[item: T, sortedNode: SortedNode<T>]>>
  >;
  ObserveIndex(indexToObserve: number): Observable<number>;
  ObserveAtIndex(
    indexToObserve: number
  ): Observable<LuaTuple<[item: T, sortedNode: SortedNode<T>]>>;
  ObserveIndexByKey(node: SortedNode<T>): Observable<number>;
  GetIndexByKey(node: SortedNode<T>): number | undefined;
  GetCount(): number;
  __len(): number;
  GetList(): T[];
  ObserveCount(): Observable<number>;
  Add(item: T, observeValue: Observable<number> | number): () => void;
  Get(index: number): T | undefined;
  RemoveByKey(node: SortedNode<T>): void;
  Destroy(): void;
}

interface ObservableSortedListConstructor {
  readonly ClassName: 'ObservableSortedList';
  new (): ObservableSortedList<never>;
  new <T>(): ObservableSortedList<T>;

  isObservableSortedList(
    value: unknown
  ): value is ObservableSortedList<unknown>;
}

export const ObservableSortedList: ObservableSortedListConstructor;
