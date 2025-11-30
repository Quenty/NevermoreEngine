import { Brio } from '../../../brio';
import { Observable } from '../../../rx';
import { Signal } from '@quenty/signal';
import { Symbol } from '../../../symbol/src/Shared/Symbol';
import { ValueObject } from '../../../valueobject';

interface ObservableSet<T> extends Iterable<T> {
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
}

interface ObservableSetConstructor {
  readonly ClassName: 'ObservableSet';
  new (): ObservableSet<never>;
  new <T>(): ObservableSet<T>;

  isObservableSet(value: unknown): value is ObservableSet<unknown>;
}

export const ObservableSet: ObservableSetConstructor;
