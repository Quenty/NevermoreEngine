import { Brio } from '../../../brio';
import { Observable } from '../../../rx';
import { Signal } from '../../../signal/src/Shared/Signal';
import { ObservableList } from './ObservableList';

interface ObservableMapList<TKey, TValue> {
  ListAdded: Signal<[key: TKey, list: ObservableList<TValue>]>;
  ListRemoved: Signal<TKey>;
  CountChanged: Signal<number>;
  Push(observeKey: Observable<TKey>, entry: TValue): () => void;
  GetFirstItemForKey(key: TKey): TValue | undefined;
  GetItemForKeyAtIndex(key: TKey, index: number): TValue | undefined;
  GetListCount(): number;
  ObserveListCount(): Observable<number>;
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
  new (): ObservableMapList<never, never>;
  new <TKey, TValue>(): ObservableMapList<TKey, TValue>;

  isObservableMapList(value: any): value is ObservableMapList<any, any>;
}

export const ObservableMapList: ObservableMapListConstructor;
