import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

type StateStack<T> = {
  GetCount(): number;
  GetState(): T;
  Observe(): Observable<T>;
  ObserveBrio(predicate?: (value: T) => boolean): Observable<Brio<T>>;
  PushState(value: T): () => void;
  PushBrio(value: Brio<[T]>): () => void;
  Destroy(): void;
};

interface StateStackConstructor {
  readonly ClassName: 'StateStack';
  new (): StateStack<unknown>;
  new <T>(defaultValue: T, checkType?: string): StateStack<T>;
}

export const StateStack: StateStackConstructor;
