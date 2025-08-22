import { Brio } from '../../../brio';
import { Observable, Predicate } from '../../../rx';

export namespace RxValueBaseUtils {
  function observeBrio<T = unknown>(
    parent: InstanceType,
    className: string,
    name: string,
    predicate?: Predicate<T>
  ): Observable<Brio<T>>;
  function observe<T = unknown>(
    parent: InstanceType,
    className: string,
    name: string,
    defaultValue?: T
  ): Observable<T>;
  function observeValue<T = unknown>(valueObject: ValueBase): Observable<T>;
}
