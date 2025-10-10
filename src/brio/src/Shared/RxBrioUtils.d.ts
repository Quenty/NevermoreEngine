import { Maid } from '@quenty/maid';
import { Observable, Operator } from '../../../rx';
import { Brio } from './Brio';

type ToTuple<T> = T extends [unknown, ...unknown[]] ? T : [T];

type FlattenValues<T extends Record<string | number, unknown>> = {
  [K in keyof T]: T[K] extends Observable<Brio<infer V>>
    ? V | undefined
    : T[K] extends Observable<infer V>
    ? V | undefined
    : T[K];
};

export namespace RxBrioUtils {
  function ofBrio<T>(callback: ((maid: Maid) => T) | T): Observable<Brio<T>>;
  function toBrio<T>(): (
    source: Observable<Brio<T> | T>
  ) => Observable<Brio<T>>;
  function of<T extends unknown[]>(...values: T): Observable<Brio<T[number]>>;
  function completeOnDeath<T>(
    brio: Brio<unknown>,
    observable: Observable<T>
  ): Observable<T>;
  function emitWhileAllDead<T, U>(
    valueToEmitWhileAllDead: T
  ): (source: Observable<Brio<U>>) => Observable<Brio<U | T>>;
  function reduceToAliveList<T, U>(
    selectFromBrio?: (value: T) => U
  ): (source: Observable<Brio<T>>) => Observable<Brio<U[]>>;
  function reemitLastBrioOnDeath<T>(): (
    source: Observable<Brio<T>>
  ) => Observable<Brio<T>>;
  function where<T>(
    predicate: (value: T) => value is NonNullable<T>
  ): Operator<Brio<T>, Brio<NonNullable<T>>>;
  function where<T>(
    predicate: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Operator<Brio<T>, Brio<Exclude<T, NonNullable<T>>>>;
  function where<T>(
    predicate: (value: T) => boolean
  ): Operator<Brio<T>, Brio<T>>;
  const filter: typeof where;
  function combineLatest<
    T extends Record<
      string | number,
      Observable<Brio<unknown>> | Observable<unknown> | unknown
    >
  >(observables: T): Observable<Brio<FlattenValues<T>>>;
  function flatCombineLatestBrio<
    T extends Record<
      string | number,
      Observable<Brio<unknown>> | Observable<unknown> | unknown
    >
  >(
    observables: T,
    filter?: (value: FlattenValues<T>) => boolean
  ): Observable<Brio<FlattenValues<T>>>;
  function flatMap<T, TProject>(
    project: (value: T) => Observable<TProject>
  ): (source: Observable<Brio<T>>) => Observable<TProject>;
  function flatMapBrio<TBrio extends Brio<unknown>, TProject>(
    project: (
      ...values: TBrio extends Brio<infer V> ? ToTuple<V> : [never]
    ) => Observable<TProject>
  ): Operator<
    TBrio,
    TProject extends Brio<unknown> ? TProject : Brio<TProject>
  >;
  function switchMap<T, TProject>(
    project: (value: T) => Observable<TProject>
  ): (source: Observable<Brio<T>>) => Observable<TProject>;
  function switchMapBrio<T, TProject>(
    project: (value: T) => Observable<TProject> | Observable<Brio<TProject>>
  ): (source: Observable<Brio<T>>) => Observable<Brio<TProject>>;
  function flatCombineLatest<T>(
    observables: Record<string, Observable<Brio<T>> | Observable<T> | T>
  ): Observable<Record<string, T | undefined>>;
  function mapBrio<TBrio extends Brio<unknown>, TProject>(
    project: (value: TBrio) => Observable<TProject>
  ): (brio: TBrio) => Observable<TProject>;
  function prepend<T>(
    ...values: T[]
  ): <U>(source: Observable<Brio<U>>) => Observable<Brio<U | T | (U & T)>>;
  function extend<T>(
    ...values: T[]
  ): <U>(source: Observable<Brio<U>>) => Observable<Brio<U | T | (U & T)>>;
  function map<T, U>(
    project: (...args: unknown[]) => U
  ): (source: Observable<Brio<T> | T>) => Observable<Brio<U>>;
  function mapBrioBrio<T, TProject>(
    project: (value: T) => Observable<TProject> | Observable<Brio<TProject>>
  ): Operator<Brio<T>, Brio<TProject extends Brio<infer V> ? V : TProject>>;
  function toEmitOnDeathObservable<T, U>(
    brio: Brio<T> | T,
    emitOnDeathValue: U
  ): Observable<T | U>;
  function mapBrioToEmitOnDeathObservable<T, U>(
    emitOnDeathValue: U
  ): (brio: Brio<T> | T) => Observable<T | U>;
  function emitOnDeath<T, U>(
    emitOnDeathValue: U
  ): (source: Observable<Brio<T> | T>) => Observable<T | U>;
  function flattenToValueAndNil<T>(
    source: Observable<Brio<T> | T>
  ): Observable<T | undefined>;
  function onlyLastBrioSurvives<T>(): (
    source: Observable<Brio<T>>
  ) => Observable<Brio<T>>;
  function switchToBrio<T>(
    predicate?: (value: T) => value is NonNullable<T>
  ): (source: Observable<T | Brio<T>>) => Observable<Brio<NonNullable<T>>>;
  function switchToBrio<T>(
    predicate?: (value: T) => value is Exclude<T, NonNullable<T>>
  ): (
    source: Observable<T | Brio<T>>
  ) => Observable<Brio<Exclude<T, NonNullable<T>>>>;
  function switchToBrio<T>(
    predicate?: (value: T) => boolean
  ): (source: Observable<T | Brio<T>>) => Observable<Brio<T>>;
}

export {};
