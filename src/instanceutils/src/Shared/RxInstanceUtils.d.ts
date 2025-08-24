import { Brio } from '../../../brio';
import { Observable, Predicate } from '../../../rx';

export namespace RxInstanceUtils {
  function observeProperty<
    T extends Instance,
    K extends keyof InstanceProperties<T>
  >(instance: T, propertyName: K): Observable<InstanceProperties<T>[K]>;
  function observeAncestry(instance: Instance): Observable<Instance>;
  function observeFirstAncestorBrio<T extends keyof Instances>(
    instance: Instance,
    className: T
  ): Observable<Brio<Instances[T]>>;
  function observeParentBrio(instance: Instance): Observable<Brio<Instance>>;
  function observeFirstAncestor<T extends keyof Instances>(
    instance: Instance,
    className: T
  ): Observable<Instances[T] | undefined>;
  function observePropertyBrio<
    T extends Instance,
    K extends keyof InstanceProperties<T>
  >(
    instance: T,
    propertyName: K,
    predicate?: (value: InstanceProperties<T>[K]) => boolean
  ): Observable<Brio<InstanceProperties<T>[K]>>;
  function observeLastNamedChildBrio<T extends keyof Instances>(
    instance: Instance,
    className: T,
    name: string
  ): Observable<Brio<Instances[T]>>;
  function observeChildrenOfNameBrio<T extends keyof Instances>(
    parent: Instance,
    className: T,
    name: string
  ): Observable<Brio<Instances[T]>>;
  function observeChildrenOfClassBrio<T extends keyof Instances>(
    parent: Instance,
    className: T
  ): Observable<Brio<Instances[T]>>;
  function observeChildrenBrio(
    parent: Instance,
    predicate?: Predicate<Instance>
  ): Observable<Brio<Instance>>;
  function observeDescendants(
    parent: Instance,
    predicate?: Predicate<Instance>
  ): Observable<[instance: Instance, wasAdded: boolean]>;
  function observeDescendantsBrio(
    parent: Instance,
    predicate?: Predicate<Instance>
  ): Observable<Brio<Instance>>;
  function observeDescendantsOfClassBrio<T extends keyof Instances>(
    parent: InstanceType,
    className: T
  ): Observable<Brio<Instances[T]>>;
}
