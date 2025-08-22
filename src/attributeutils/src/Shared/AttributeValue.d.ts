import { Brio } from '../../../brio';
import { Observable } from '../../../rx';
import { Signal } from '../../../signal/src/Shared/Signal';

interface AttributeValue<T> {
  Value: T;
  Changed: Signal<T>;
  Observe(): Observable<T>;
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
