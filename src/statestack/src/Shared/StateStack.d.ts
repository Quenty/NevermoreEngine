import { BaseObject } from '@quenty/baseobject';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

interface StateStack<T> extends BaseObject {
  GetCount(): number;
  GetState(): T;
  Observe(): Observable<T>;
  ObserveBrio(): Observable<Brio<T>>;
  ObserveBrio(
    predicate?: (value: T) => value is NonNullable<T>
  ): Observable<Brio<NonNullable<T>>>;
  ObserveBrio(
    predicate?: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Observable<Brio<Exclude<T, NonNullable<T>>>>;
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
