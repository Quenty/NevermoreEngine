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
    attributeName: string
  ): Observable<Brio<T>>;
  function observeAttributeBrio<T extends AttributeValue | undefined>(
    instance: Instance,
    attributeName: string,
    predicate?: (value: T) => value is NonNullable<T>
  ): Observable<Brio<NonNullable<T>>>;
  function observeAttributeBrio<T extends AttributeValue | undefined>(
    instance: Instance,
    attributeName: string,
    predicate?: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Observable<Brio<Exclude<T, NonNullable<T>>>>;
  function observeAttributeBrio<T extends AttributeValue | undefined>(
    instance: Instance,
    attributeName: string,
    predicate: (value: T) => boolean
  ): Observable<Brio<T>>;
}
