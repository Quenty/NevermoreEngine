import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

interface EncodedAttributeValue<T> {
  Value: T;
  Changed: Signal<[T]>;
  Observe(): Observable<[T]>;
  ObserveBrio(condition?: (value: T) => boolean): Observable<[Brio<[T]>]>;
  Destroy(): void;
}

interface EncodedAttributeValueConstructor {
  readonly ClassName: 'EncodedAttributeValue';
  new <T>(
    object: Instance,
    attributeName: string,
    encode: (value: T) => string,
    decode: (value: string) => T,
    defaultValue: T
  ): EncodedAttributeValue<T>;
}

export const EncodedAttributeValue: EncodedAttributeValueConstructor;
