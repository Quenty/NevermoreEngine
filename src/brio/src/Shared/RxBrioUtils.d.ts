import { Maid } from '../../../maid';
import { Observable } from '../../../rx';
import { Brio } from './Brio';

export namespace RxBrioUtils {
  function ofBrio<T extends unknown[]>(
    callback: ((maid: Maid) => T) | T
  ): Observable<[Brio<T>]>;
  function toBrio<T extends unknown[]>(): (
    source: Observable<[Brio<T> | T]>
  ) => Observable<[Brio<T>]>;
  function of<T extends unknown[]>(...values: T): Observable<[Brio<T>]>;
  function completeOnDeath<T extends unknown[]>(
    brio: Brio<unknown[]>,
    observable: Observable<T>
  ): Observable<T>;
  function emitWhileAllDead<T extends unknown[], U extends unknown[]>(
    valueToEmitWhileAllDead: T
  ): (source: Observable<[Brio<U>]>) => Observable<[Brio<U | T>]>;
  function reduceToAliveList<T extends unknown[], U extends unknown[]>(
    selectFromBrio?: (value: T) => U
  ): (source: Observable<[Brio<T>]>) => Observable<[Brio<U[]>]>;
  function reemitLastBrioOnDeath<T extends unknown[]>(): (
    source: Observable<[Brio<T>]>
  ) => Observable<[Brio<T>]>;
  function where<T extends unknown[]>(
    predicate: (value: T) => boolean
  ): (source: Observable<[Brio<T>]>) => Observable<[Brio<T>]>;
  const filter: typeof where;
  function combineLatest<T extends unknown[]>(
    observables: Record<string, Observable<[Brio<T>]> | Observable<T> | T>
  ): Observable<[Brio<[Record<string, T>]>]>;
  function flatCombineLatestBrio<T extends unknown[]>(
    observables: Record<string, Observable<[Brio<T>]> | Observable<T> | T>,
    filter?: (value: T) => boolean
  ): Observable<[Brio<[Record<string, T>]>]>;
  function flatMap<TBrio extends Brio<unknown[]>, TProject extends unknown[]>(
    project: (value: TBrio) => Observable<TProject>
  ): (source: Observable<[TBrio]>) => Observable<TProject>;
  function flatMapBrio<
    TBrio extends Brio<unknown[]>,
    TProject extends unknown[]
  >(
    project: (
      value: TBrio
    ) => Observable<TProject> | Observable<[Brio<TProject>]>
  ): (source: Observable<[TBrio]>) => Observable<[Brio<TProject>]>;
  function switchMap<TBrio extends Brio<unknown[]>, TProject extends unknown[]>(
    project: (value: TBrio) => Observable<TProject>
  ): (source: Observable<[TBrio]>) => Observable<TProject>;
  function switchMapBrio<
    TBrio extends Brio<unknown[]>,
    TProject extends unknown[]
  >(
    project: (
      value: TBrio
    ) => Observable<TProject> | Observable<[Brio<TProject>]>
  ): (source: Observable<[TBrio]>) => Observable<[Brio<TProject>]>;
  function flatCombineLatest<T extends unknown[]>(
    observables: Record<string, Observable<[Brio<T>]> | Observable<T> | T>
  ): Observable<[Record<string, T | undefined>]>;
  function mapBrio<TBrio extends Brio<unknown[]>, TProject extends unknown[]>(
    project: (value: TBrio) => Observable<TProject>
  ): (brio: TBrio) => Observable<TProject>;
  function prepend<T extends unknown[]>(
    ...values: T
  ): <U extends unknown[]>(
    source: Observable<[Brio<U>]>
  ) => Observable<[Brio<U | T>]>;
  function extend<T extends unknown[]>(
    ...values: T
  ): <U extends unknown[]>(
    source: Observable<[Brio<U>]>
  ) => Observable<[Brio<U | T>]>;
  function map<T extends unknown[], U extends unknown[]>(
    project: (...args: any[]) => U
  ): (source: Observable<[Brio<T> | T]>) => Observable<[Brio<U>]>;
  function mapBrioBrio<
    TBrio extends Brio<unknown[]>,
    TProject extends unknown[]
  >(
    project: (
      value: TBrio
    ) => Observable<TProject> | Observable<[Brio<TProject>]>
  ): (brio: TBrio) => Observable<[Brio<TProject>]>;
  function toEmitOnDeathObservable<T extends unknown[], U>(
    brio: Brio<T> | T,
    emitOnDeathValue: U
  ): Observable<[T | U]>;
  function mapBrioToEmitOnDeathObservable<T extends unknown[], U>(
    emitOnDeathValue: U
  ): (brio: Brio<T> | T) => Observable<[T | U]>;
  function emitOnDeath<T extends unknown[], U>(
    emitOnDeathValue: U
  ): (source: Observable<[Brio<T> | T]>) => Observable<[T | U]>;
  function flattenToValueAndNil<T extends unknown[]>(
    source: Observable<[Brio<T> | T]>
  ): Observable<[T | undefined]>;
  function onlyLastBrioSurvives<T extends unknown[]>(): (
    source: Observable<[Brio<T>]>
  ) => Observable<[Brio<T>]>;
  function switchToBrio<T extends unknown[]>(
    predicate?: (...values: T) => boolean
  ): (source: Observable<T | [Brio<T>]>) => Observable<[Brio<T>]>;
}
