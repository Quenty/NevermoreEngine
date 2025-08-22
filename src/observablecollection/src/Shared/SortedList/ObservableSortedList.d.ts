import { Brio } from '../../../../brio';
import { Observable } from '../../../../rx';
import { Signal } from '../../../../signal/src/Shared/Signal';
import { Symbol } from '../../../../symbol/src/Shared/Symbol';
import { SortedNode } from './SortedNode';

interface ObservableSortedList<T> extends Iterable<T> {
  ItemAdded: Signal<[item: T, index: number, key: Symbol]>;
  ItemRemoved: Signal<[item: T, key: Symbol]>;
  OrderChanged: Signal;
  CountChanged: Signal<number>;
  Observe(): Observable<T[]>;
  IterateRange(start: number, finish: number): Iterable<T>;
  FindFirstKey(item: T): SortedNode<T> | undefined;
  PrintDebug(): void;
  Contains(item: T): boolean;
  ObserveItemsBrio(): Observable<Brio<[item: T, sortedNode: SortedNode<T>]>>;
  ObserveIndex(indexToObserve: number): Observable<number>;
  ObserveAtIndex(
    indexToObserve: number
  ): Observable<[item: T, sortedNode: SortedNode<T>]>;
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

  isObservableSortedList(value: any): value is ObservableSortedList<any>;
}

export const ObservableSortedList: ObservableSortedListConstructor;
