import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Symbol } from '@quenty/symbol';
import { ValueObject } from '@quenty/valueobject';

interface ObservableList<T> extends Iterable<T> {
  Observe(): Observable<T[]>;
  ObserveItemsBrio(): Observable<Brio<[T, Symbol]>>;
  ObserveIndex(indexToObserve: number): Observable<number | undefined>;
  ObserveAtIndex(indexToObserve: number): Observable<T | undefined>;
  ObserveAtIndexBrio(indexToObserve: number): Observable<Brio<T>>;
  RemoveFirst(item: T): boolean;
  GetCountValue(): ValueObject<number>;
  ObserveIndexByKey(key: Symbol): Observable<number | undefined>;
  GetIndexByKey(key: Symbol): number | undefined;
  GetCount(): number;
  ObserveCount(): Observable<number>;
  Add(item: T): () => void;
  Get(index: number): T | undefined;
  InsertAt(item: T, index: number): () => void;
  RemoveAt(index: number): T | undefined;
  RemoveByKey(key: Symbol): T | undefined;
  GetList(): T[];
  Destroy(): void;
}

interface ObservableListConstructor {
  readonly ClassName: 'ObservableList';
  new (): ObservableList<never>;
  new <T>(): ObservableList<T>;

  isObservableList(value: unknown): value is ObservableList<unknown>;
}

export const ObservableList: ObservableListConstructor;
