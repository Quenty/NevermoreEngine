import { Signal } from '@quenty/signal';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

type ObservableSet<T> = {
  ItemAdded: Signal<T>;
  ItemRemoved: Signal<T>;
  CountChanged: Signal<number>;
  ObserveItemsBrio(): Observable<Brio<T>>;
  ObserveContains(item: T): Observable<boolean>;
  Contains(item: T): boolean;
  GetCount(): number;
  ObserveCount(): Observable<number>;
  Add(item: T): () => void;
  Remove(item: T): void;
  GetFirstItem(): T | undefined;
  GetList(): T[];
  GetSetCopy(): Map<T, true>;
  GetRawSet(): ReadonlyMap<T, true>;
  Destroy(): void;
} & IterableFunction<T>;

interface ObservableSetConstructor {
  readonly ClassName: 'ObservableSet';
  new (): ObservableSet<never>;
  new <T>(): ObservableSet<T>;

  isObservableSet(value: unknown): value is ObservableSet<unknown>;
}

export const ObservableSet: ObservableSetConstructor;
