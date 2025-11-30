import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { ObservableList } from './ObservableList';
import { Maid } from '@quenty/maid';

interface ObservableMapList<TKey, TValue> {
  ListAdded: Signal<[key: TKey, list: ObservableList<TValue>]>;
  ListRemoved: Signal<TKey>;
  CountChanged: Signal<number>;
  Push(key: TKey | Observable<TKey>, entry: TValue): Maid;
  GetFirstItemForKey(key: TKey): TValue | undefined;
  GetItemForKeyAtIndex(key: TKey, index: number): TValue | undefined;
  GetListCount(): number;
  ObserveListCount(): Observable<number>;
  GetKeyList(): TKey[];
  ObserveKeyList(): Observable<TKey[]>;
  ObserveKeysBrio(): Observable<Brio<TKey>>;
  GetAtListIndex(key: TKey, index: number): TValue | undefined;
  ObserveAtListIndex(key: TKey, index: number): Observable<TValue | undefined>;
  ObserveAtListIndexBrio(key: TKey, index: number): Observable<Brio<TValue>>;
  ObserveItemsForKeyBrio(key: TKey): Observable<Brio<TValue>>;
  GetListFromKey(key: TKey): TValue[];
  GetListForKey(key: TKey): TValue[];
  GetListOfValuesAtListIndex(index: number): TValue[];
  ObserveList(key: TKey): Observable<ObservableList<TValue>>;
  ObserveListBrio(key: TKey): Observable<Brio<ObservableList<TValue>>>;
  ObserveListsBrio(): Observable<Brio<ObservableList<TValue>>>;
  ObserveCountForKey(key: TKey): Observable<number>;
  Destroy(): void;
}

interface ObservableMapListConstructor {
  readonly ClassName: 'ObservableMapList';
  new (): ObservableMapList<unknown, unknown>;
  new <TKey, TValue>(): ObservableMapList<TKey, TValue>;

  isObservableMapList(
    value: unknown
  ): value is ObservableMapList<unknown, unknown>;
}

export const ObservableMapList: ObservableMapListConstructor;
