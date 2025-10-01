import { Brio } from '@quenty/brio';
import { MaidTask } from '@quenty/maid';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

type CheckType =
  | keyof CheckableTypes
  | ((value: unknown) => LuaTuple<[boolean, string?]>);

export type Mountable<T> = T | Observable<T> | ValueBase | ValueObject<T>;

interface ValueObject<T> {
  Value: T;
  Changed: Signal<T>;
  GetCheckType(): CheckType | undefined;
  Mount(value: T | Observable<T>): MaidTask;
  Observe(): Observable<T>;
  ObserveBrio(
    condition?: (value: T) => value is NonNullable<T>
  ): Observable<Brio<NonNullable<T>>>;
  ObserveBrio(
    condition?: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Observable<Brio<Exclude<T, NonNullable<T>>>>;
  ObserveBrio(condition?: (value: T) => boolean): Observable<Brio<T>>;
  SetValue(value: T): void;
  Destroy(): void;
}

interface ValueObjectConstructor {
  readonly ClassName: 'ValueObject';
  new <T>(value: T, checkType?: CheckType): ValueObject<T>;

  fromObservable: <T>(observable: Observable<T>) => ValueObject<T>;
  isValueObject: (value: unknown) => value is ValueObject<unknown>;
}

export const ValueObject: ValueObjectConstructor;
