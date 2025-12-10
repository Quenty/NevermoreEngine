import { Brio } from '@quenty/brio';
import { MaidTask } from '@quenty/maid';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

export interface ValueObjectLike<T> {
  Value: T;
  Observe(): Observable<T>;
  ObserveBrio(
    predicate?: (value: T) => value is NonNullable<T>
  ): Observable<Brio<NonNullable<T>>>;
  ObserveBrio(
    predicate?: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Observable<Brio<Exclude<T, NonNullable<T>>>>;
  ObserveBrio(predicate?: (value: T) => boolean): Observable<Brio<T>>;
}

type CheckType =
  | keyof CheckableTypes
  | ((value: unknown) => LuaTuple<[boolean, string?]>);

export type Mountable<T> = T | Observable<T> | ValueBase | ValueObject<T>;

export interface ValueObject<T> extends ValueObjectLike<T> {
  Value: T;
  Changed: Signal<LuaTuple<[newValue: T, oldValue: T, ...args: unknown[]]>>;
  GetCheckType(): CheckType | undefined;
  Mount(value: T | Observable<T>): MaidTask;
  SetValue(value: T): void;
  Destroy(): void;
}

interface ValueObjectConstructor {
  readonly ClassName: 'ValueObject';
  new <T = unknown>(): ValueObject<T>;
  new <T>(value: T, checkType?: CheckType): ValueObject<T>;

  fromObservable: <T>(observable: Observable<T>) => ValueObject<T>;
  isValueObject: (value: unknown) => value is ValueObject<unknown>;
}

export const ValueObject: ValueObjectConstructor;

export {};
