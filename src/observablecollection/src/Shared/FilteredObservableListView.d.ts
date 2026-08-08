import { Brio } from '../../../brio';
import { Observable } from '../../../rx';
import { Symbol } from '../../../symbol/src/Shared/Symbol';

interface FilteredObservableListView<T> {
  ObserveItemsBrio(): Observable<Brio<T>>;
  ObserveIndexByKey(key: Symbol): Observable<number>;
  GetCount(): number;
  ObserveCount(): Observable<number>;
  Destroy(): void;
}

interface FilteredObservableListViewConstructor {
  readonly ClassName: 'FilteredObservableListView';
  new (): FilteredObservableListView<never>;
  new <T>(): FilteredObservableListView<T>;
}

export const FilteredObservableListView: FilteredObservableListViewConstructor;
