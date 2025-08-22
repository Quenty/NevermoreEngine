import { Brio } from '../../../brio';
import { Observable, Predicate } from '../../../rx';

export namespace RxInstanceUtils {
  function observeProperty<T extends Instance, K extends keyof InstanceProperties<T>>(
    instance: T,
    propertyName: K
  ): Observable<InstanceProperties<T>[K]>;
  function observeAncestry(instance: Instance): Observable<Instance>;
  function observeFirstAncestorBrio(
    instance: Instance,
    className: string
  ): Observable<Brio<Instance>>;
  function observeParentBrio(instance: Instance): Observable<Brio<Instance>>;
  function observeFirstAncestor(
    instance: Instance,
    className: string
  ): Observable<Instance | undefined>;
  function observePropertyBrio<T extends Instance, K extends keyof InstanceProperties<T>>(
    instance: T,
    propertyName: K,
    predicate?: (value: InstanceProperties<T>[K]) => boolean
  ): Observable<Brio<InstanceProperties<T>[K]>>;
  function observeLastNamedChildBrio(
    instance: Instance,
    className: string,
    name: string
  ): Observable<Brio<Instance>>;
  function observeChildrenOfNameBrio(
    parent: Instance,
    className: string,
    name: string
  ): Observable<Brio<Instance>>;
  function observeChildrenOfClassBrio(
    parent: Instance,
    className: string
  ): Observable<Brio<Instance>>;
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
  function observeDescendantsOfClassBrio
}
