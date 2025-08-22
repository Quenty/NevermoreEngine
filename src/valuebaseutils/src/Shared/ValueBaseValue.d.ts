import { Brio } from '../../../brio';
import { Observable, Predicate } from '../../../rx';
import { Signal } from '../../../signal/src/Shared/Signal';
import { ValueBaseType } from './ValueBaseUtils';

type ValueBaseValue<T> = {
  readonly Changed: Signal<T>;
  Value: T;
  ObserveBrio(predicate?: Predicate<T>): Observable<Brio<T>>;
  Observe(): Observable<T>;
};

interface ValueBaseValueConstructor {
  readonly ClassName: 'ValueBaseValue';
  new <T = unknown>(
    parent: Instance,
    className: ValueBaseType,
    name: string,
    defaultValue?: T
  ): ValueBaseValue<T>;
}

export const ValueBaseValue: ValueBaseValueConstructor;
