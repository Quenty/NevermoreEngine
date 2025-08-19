import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

export namespace RxAttributeUtils {
  function observeAttribute<T>(
    instance: Instance,
    attributeName: string,
    defaultValue?: T
  ): Observable<[T]>;
  function observeAttributeKeysBrio(
    instance: Instance
  ): Observable<[Brio<[string]>]>;
  function observeAttributeKeys(instance: Instance): Observable<[string]>;
  function observeAttributeBrio<T>(
    instance: Instance,
    attributeName: string,
    condition?: (value: T) => boolean
  ): Observable<[Brio<[T]>]>;
}
