import { Maid } from '../../../maid';
import { Brio } from './Brio';

export const ofBrio: <T>(
  callback: ((maid: Maid) => T) | T
) => Observable<Brio<T>>;
export const toBrio: <T>() => (
  source: Observable<Brio<T> | T>
) => Observable<Brio<T>>;
export const of: <T extends unknown[]>(...values: T) => Observable<Brio<T>>;
export const completeOnDeath: <T>(
  brio: Brio<unknown[]>,
  observable: Observable<T>
) => Observable<T>;
export const emitWhileAllDead: <T, U>(
  valueToEmitWhileAllDead: T
) => (source: Observable<Brio<U>>) => Observable<Brio<U | T>>;
export const reduceToAliveList: <T, U>(
  selectFromBrio?: (value: T) => U
) => (source: Observable<Brio<T>>) => Observable<Brio<U[]>>;
export const reemitLastBrioOnDeath: <T>() => (
  source: Observable<Brio<T>>
) => Observable<Brio<T>>;
export const where: <T>(
  predicate: (value: T) => boolean
) => (source: Observable<Brio<T>>) => Observable<Brio<T>>;
export const filter: typeof where;
export const combineLatest: <T>(
  observables: Record<string, Observable<Brio<T>> | Observable<T> | T>
) => Observable<Brio<Record<string, T>>>;
export const flatCombineLatestBrio: <T>(
  observables: Record<string, Observable<Brio<T>> | Observable<T> | T>,
  filter?: (value: T) => boolean
) => Observable<Brio<Record<string, T>>>;
export const flatMap: <TBrio, TProject>(
  project: (value: TBrio) => Observable<TProject>
) => (source: Observable<Brio<TBrio>>) => Observable<TProject>;
export const flatMapBrio: <TBrio, TProject>(
  project: (value: TBrio) => Observable<TProject> | Observable<Brio<TProject>>
) => (source: Observable<Brio<TBrio>>) => Observable<Brio<TProject>>;
export const switchMap: <TBrio, TProject>(
  project: (value: TBrio) => Observable<TProject>
) => (source: Observable<Brio<TBrio>>) => Observable<TProject>;
export const switchMapBrio: <TBrio, TProject>(
  project: (value: TBrio) => Observable<TProject> | Observable<Brio<TProject>>
) => (source: Observable<Brio<TBrio>>) => Observable<Brio<TProject>>;
export const flatCombineLatest: <T>(
  observables: Record<string, Observable<Brio<T>> | Observable<T> | T>
) => Observable<Record<string, T | undefined>>;
export const mapBrio: <TBrio, TProject>(
  project: (value: TBrio) => Observable<TProject>
) => (brio: Brio<TBrio>) => Observable<TProject>;
export const prepend: <T extends unknown[]>(
  ...values: T
) => <U>(source: Observable<Brio<U>>) => Observable<Brio<U | T>>;
export const extend: <T extends unknown[]>(
  ...values: T
) => <U>(source: Observable<Brio<U>>) => Observable<Brio<U | T>>;
export const map: <T, U>(
  project: (...args: any[]) => U
) => (source: Observable<Brio<T> | T>) => Observable<Brio<U>>;
export const mapBrioBrio: <TBrio, TProject>(
  project: (value: TBrio) => Observable<TProject> | Observable<Brio<TProject>>
) => (brio: Brio<TBrio>) => Observable<Brio<TProject>>;
export const toEmitOnDeathObservable: <T, U>(
  brio: Brio<T> | T,
  emitOnDeathValue: U
) => Observable<T | U>;
export const mapBrioToEmitOnDeathObservable: <T, U>(
  emitOnDeathValue: U
) => (brio: Brio<T> | T) => Observable<T | U>;
export const emitOnDeath: <T, U>(
  emitOnDeathValue: U
) => (source: Observable<Brio<T> | T>) => Observable<T | U>;
export const flattenToValueAndNil: <T>(
  source: Observable<Brio<T> | T>
) => Observable<T | undefined>;
export const onlyLastBrioSurvives: <T>() => (
  source: Observable<Brio<T>>
) => Observable<Brio<T>>;
export const switchToBrio: <T>(
  predicate?: (value: T) => boolean
) => (source: Observable<T | Brio<T>>) => Observable<Brio<T>>;
