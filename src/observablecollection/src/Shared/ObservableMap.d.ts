import { Brio } from '../../../brio';
import { Observable } from '../../../rx';
import { Signal } from '@quenty/signal';

interface ObservableMap<TKey, TValue> extends Iterable<[TKey, TValue]> {
  CountChanged: Signal<number>;
  ObserveKeysBrio(): Observable<Brio<TKey>>;
  ObserveValuesBrio(): Observable<Brio<TValue>>;
  ObservePairsBrio(): Observable<Brio<[key: TKey, value: TValue]>>;
  Get(key: TKey): TValue | undefined;
  ContainsKey(key: TKey): boolean;
  GetCount(): number;
  ObserveCount(): Observable<number>;
  ObserveAtKeyBrio(key: TKey): Observable<Brio<TValue>>;
  ObserveAtKey(key: TKey): Observable<TValue | undefined>;
  ObserveValueForKey(key: TKey): Observable<TValue | undefined>;
  Set(key: TKey, value?: TValue): () => void;
  Remove(key: TKey): void;
  GetValueList(): TValue[];
  GetKeyList(): TKey[];
  ObserveKeyList(): Observable<TKey[]>;
  Destroy(): void;
}

interface ObservableMapConstructor {
  readonly ClassName: 'ObservableMap';
  new (): ObservableMap<unknown, unknown>;
  new <TKey, TValue>(): ObservableMap<TKey, TValue>;

  isObservableMap(value: unknown): value is ObservableMap<unknown, unknown>;
}

export const ObservableMap: ObservableMapConstructor;
