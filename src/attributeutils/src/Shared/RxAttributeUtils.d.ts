import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxAttributeUtils {
  function observeAttribute<T extends AttributeValue | undefined>(
    instance: Instance,
    attributeName: string,
    defaultValue?: T
  ): Observable<T>;
  function observeAttributeKeysBrio(
    instance: Instance
  ): Observable<Brio<string>>;
  function observeAttributeKeys(instance: Instance): Observable<string>;
  function observeAttributeBrio<T extends AttributeValue | undefined>(
    instance: Instance,
    attributeName: string,
    condition?: (value: T) => boolean
  ): Observable<Brio<T>>;
}
