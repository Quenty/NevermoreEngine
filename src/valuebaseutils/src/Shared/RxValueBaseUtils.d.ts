import { Brio } from '../../../brio';
import { Observable, Predicate } from '../../../rx';

export namespace RxValueBaseUtils {
  function observeBrio<C extends keyof Instances, V = unknown>(
    parent: Instance,
    className: C,
    name: string,
    predicate?: Predicate<V>
  ): Observable<Brio<LuaTuple<[value: V, instance: Instances[C]]>>>;
  function observe<C extends keyof Instances, V = unknown>(
    parent: Instance,
    className: C,
    name: string,
    defaultValue?: V
  ): Observable<LuaTuple<[value: V, instance: Instances[C]]>>;
  function observeValue<T = unknown>(valueObject: ValueBase): Observable<T>;
}
