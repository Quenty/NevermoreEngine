import { Brio } from '../../../brio';
import { Observable } from '../../../rx';
import { StateStack } from './StateStack';

export namespace RxStateStackUtils {
  function topOfStack<T extends unknown[]>(
    defaultValue: T
  ): (source: Observable<Brio<T>>) => Observable<T>;
  function createStateStack<T extends unknown[]>(
    observable: Observable<Brio<T>>
  ): StateStack<T>;
}
