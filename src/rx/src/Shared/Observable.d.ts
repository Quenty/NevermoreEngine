import { MaidTask } from '../../../maid';
import { Subscription } from './Subscription';

type Observable<T = void> = {
  Subscribe(): Subscription<T>;
  Pipe<U extends unknown[]>(
    ...operators: ((subscription: Subscription<T>) => Subscription<U>)[]
  ): Observable<U>;
  Subscribe(
    fireCallback?: (...args: T extends unknown[] ? T : [T]) => void,
    failCallback?: () => void,
    completeCallback?: () => void
  ): Subscription<T>;
};

interface ObservableConstructor {
  readonly ClassName: 'Observable';
  new <T>(
    onSubscribe: (subscription: Subscription<T>) => MaidTask
  ): Observable<T>;

  isObservable: (item: any) => item is Observable;
}

export const Observable: ObservableConstructor;
