import { Brio } from '@quenty/brio';
import { Observable, Predicate } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface PropertyValue<
  I extends Instance,
  P extends keyof InstanceProperties<I>,
  V extends InstanceProperties<I>[P] = InstanceProperties<I>[P]
> {
  Value: V;
  readonly Changed: Signal<V>;
  Observe(): Observable<V>;
  ObserveBrio(condition?: Predicate<V>): Observable<Brio<V>>;
}

interface PropertyValueConstructor {
  readonly ClassName: 'PropertyValue';
  new <I extends Instance, P extends keyof InstanceProperties<I>>(
    instance: I,
    propertyName: P
  ): PropertyValue<I, P>;
}

export const PropertyValue: PropertyValueConstructor;
