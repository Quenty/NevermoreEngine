import { RxSignal } from '@quenty/rxsignal';
import { ValueBaseType } from './ValueBaseUtils';

interface ValueBaseValue<T> {
  Value: T;
  Changed: RxSignal<LuaTuple<[value: T, instance: Instance]>>;
  Observe(): Observable<LuaTuple<[value: T, instance: Instance]>>;
  ObserveBrio(): Observable<Brio<LuaTuple<[value: T, instance: Instance]>>>;
  ObserveBrio(
    predicate: (value: T) => value is NonNullable<T>
  ): Observable<Brio<LuaTuple<[value: NonNullable<T>, instance: Instance]>>>;
  ObserveBrio(
    predicate: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Observable<
    Brio<LuaTuple<[value: Exclude<T, NonNullable<T>>, instance: Instance]>>
  >;
  ObserveBrio(
    predicate: (value: T) => boolean
  ): Observable<Brio<LuaTuple<[value: T, instance: Instance]>>>;
}

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
