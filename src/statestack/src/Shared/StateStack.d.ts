import { BaseObject } from '../../../baseobject';
import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

interface StateStack<T> extends BaseObject {
  GetCount(): number;
  GetState(): T;
  Observe(): Observable<T>;
  ObserveBrio(predicate?: (value: T) => boolean): Observable<Brio<T>>;
  PushState(value: T): () => void;
  PushBrio(value: Brio<T>): () => void;
}

interface StateStackConstructor {
  readonly ClassName: 'StateStack';
  new <T>(): StateStack<T>;
  new <T>(defaultValue: T, checkType?: string): StateStack<T>;
}

export const StateStack: StateStackConstructor;
