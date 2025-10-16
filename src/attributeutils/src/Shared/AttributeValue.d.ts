import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface AttributeValue<T> {
  Value: T;
  Changed: Signal;
  Observe(): Observable<T>;
  ObserveBrio(
    condition: (value: T) => value is NonNullable<T>
  ): Observable<Brio<NonNullable<T>>>;
  ObserveBrio(
    condition: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Observable<Brio<Exclude<T, NonNullable<T>>>>;
  ObserveBrio(condition?: (value: T) => boolean): Observable<Brio<T>>;
  Destroy(): void;
}

interface AttributeValueConstructor {
  readonly ClassName: 'AttributeValue';
  new <T = unknown>(
    object: Instance,
    attributeName: string,
    defaultValue?: T
  ): AttributeValue<T>;
}

export const AttributeValue: AttributeValueConstructor;
