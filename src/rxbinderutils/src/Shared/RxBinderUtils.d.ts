import { Binder } from '@quenty/binder';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx/src/Shared/Observable';

export namespace RxBinderUtils {
  function observeLinkedBoundClassBrio<T>(
    linkName: string,
    parent: Instance,
    binder: Binder<T>
  ): Observable<Brio<T>>;
  function observeChildrenBrio<T>(
    binder: Binder<T>,
    instance: Instance
  ): Observable<Brio<T>>;
  const observeBoundChildClassBrio: typeof observeChildrenBrio;
  function observeBoundParentClassBrio<T>(
    binder: Binder<T>,
    instance: Instance
  ): Observable<Brio<T>>;
  function observeBoundChildClassesBrio<T extends unknown[]>(
    binders: { [K in keyof T]: Binder<T[K]> },
    instance: Instance
  ): Observable<Brio<T[number]>>;
  function observeBoundClass<T>(
    binder: Binder<T>,
    instance: Instance
  ): Observable<T | undefined>;
  function observeBoundClassBrio<T>(
    binder: Binder<T>,
    instance: Instance
  ): Observable<Brio<T>>;
  function observeBoundClassesBrio<T extends unknown[]>(
    binders: { [K in keyof T]: Binder<T[K]> },
    instance: Instance
  ): Observable<Brio<T[number]>>;
  function observeAllBrio<T>(binder: Binder<T>): Observable<Brio<T>>;
  function observeAllArrayBrio<T>(binder: Binder<T>): Observable<Brio<T[]>>;
}
