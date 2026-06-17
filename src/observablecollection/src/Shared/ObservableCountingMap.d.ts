import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

interface ObservableCountingMap<T> extends Iterable<T> {
  ObserveKeysList(): Observable<T[]>;
  ObserveKeysSet(): Observable<Map<T, true>>;
  ObservePairsBrio(): Observable<Brio<[T, number]>>;
  ObserveAtKey(key: T): Observable<number>;
  ObserveKeysBrio(): Observable<Brio<T>>;
  Contains(key: T): boolean;
  Get(key: T): number;
  GetTotalKeyCount(): number;
  ObserveTotalKeyCount(): Observable<number>;
  Set(key: T, amount?: number): () => void;
  Remove(key: T, amount?: number): () => void;
  GetFirstKey(): T | undefined;
  GetKeyList(): T[];
  Destroy(): void;
}

interface ObservableCountingMapConstructor {
  readonly ClassName: 'ObservableCountingMap';
  new (): ObservableCountingMap<never>;
  new <T>(): ObservableCountingMap<T>;

  isObservableMap(value: unknown): value is ObservableCountingMap<unknown>;
}

export const ObservableCountingMap: ObservableCountingMapConstructor;
