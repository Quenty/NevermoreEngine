import { Brio } from '@quenty/brio';
import { Observable, Predicate } from '@quenty/rx';

export namespace RxInstanceUtils {
  function observeProperty<
    T extends Instance,
    K extends keyof InstanceProperties<T>,
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
    K extends keyof InstanceProperties<T>,
  >(
    instance: T,
    propertyName: K,
    predicate: (
      value: InstanceProperties<T>[K]
    ) => value is NonNullable<InstanceProperties<T>[K]>
  ): Observable<Brio<NonNullable<InstanceProperties<T>[K]>>>;
  function observePropertyBrio<
    T extends Instance,
    K extends keyof InstanceProperties<T>,
  >(
    instance: T,
    propertyName: K,
    predicate: (
      value: InstanceProperties<T>[K]
    ) => value is Exclude<
      InstanceProperties<T>[K],
      NonNullable<InstanceProperties<T>[K]>
    >
  ): Observable<
    Brio<
      Exclude<InstanceProperties<T>[K], NonNullable<InstanceProperties<T>[K]>>
    >
  >;
  function observePropertyBrio<
    T extends Instance,
    K extends keyof InstanceProperties<T>,
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

  function observeChildrenBrio<T extends Instance>(
    parent: Instance,
    predicate: (instance: Instance) => instance is T
  ): Observable<Brio<T>>;
  function observeChildrenBrio(
    parent: Instance,
    predicate?: Predicate<Instance>
  ): Observable<Brio<Instance>>;

  function observeDescendants<T extends Instance>(
    parent: Instance,
    predicate: (instance: Instance) => instance is T
  ): Observable<LuaTuple<[instance: T, wasAdded: boolean]>>;
  function observeDescendants(
    parent: Instance,
    predicate?: Predicate<Instance>
  ): Observable<LuaTuple<[instance: Instance, wasAdded: boolean]>>;

  function observeDescendantsBrio(
    parent: Instance,
    predicate?: Predicate<Instance>
  ): Observable<Brio<Instance>>;
  function observeDescendantsOfClassBrio<T extends keyof Instances>(
    parent: Instance,
    className: T
  ): Observable<Brio<Instances[T]>>;

  function observeDescendantsAndSelfBrio<T extends Instance>(
    parent: Instance,
    predicate: (instance: Instance) => instance is T
  ): Observable<Brio<T>>;
  function observeDescendantsAndSelfBrio(
    parent: Instance,
    predicate?: Predicate<Instance>
  ): Observable<Brio<Instance>>;
}
