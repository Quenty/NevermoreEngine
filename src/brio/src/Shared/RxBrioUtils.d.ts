import { Maid } from "../../../maid";
import { Brio } from "./Brio";

export declare const ofBrio: <T>(callback: ((maid: Maid) => T) | T) => Observable<Brio<T>>;
export declare const toBrio: <T>() => (source: Observable<Brio<T> | T>) => Observable<Brio<T>>;
export declare const of: <T extends unknown[]>(...values: T) => Observable<Brio<T>>;
export declare const completeOnDeath: <T>(
    brio: Brio<unknown[]>,
    observable: Observable<T>
) => Observable<T>;
export declare const emitWhileAllDead: <T, U>(
    valueToEmitWhileAllDead: T
) => (source: Observable<Brio<U>>) => Observable<Brio<U | T>>;
export declare const reduceToAliveList: <T, U>(
    selectFromBrio?: (value: T) => U
) => (source: Observable<Brio<T>>) => Observable<Brio<U[]>>;
export declare const reemitLastBrioOnDeath: <T>() => (source: Observable<Brio<T>>) => Observable<Brio<T>>;
export declare const where: <T>(
    predicate: (value: T) => boolean
) => (source: Observable<Brio<T>>) => Observable<Brio<T>>;
export declare const filter: typeof where;
export declare const combineLatest: <T>(
    observables: Record<string, Observable<Brio<T>> | Observable<T> | T>
) => Observable<Brio<Record<string, T>>>;
export declare const flatCombineLatestBrio: <T>(
    observables: Record<string, Observable<Brio<T>> | Observable<T> | T>,
    filter?: (value: T) => boolean
) => Observable<Brio<Record<string, T>>>;
export declare const flatMap: <TBrio, TProject>(
    project: (value: TBrio) => Observable<TProject>
) => (source: Observable<Brio<TBrio>>) => Observable<TProject>;
export declare const flatMapBrio: <TBrio, TProject>(
    project: (value: TBrio) => Observable<TProject> | Observable<Brio<TProject>>
) => (source: Observable<Brio<TBrio>>) => Observable<Brio<TProject>>;
export declare const switchMap: <TBrio, TProject>(
    project: (value: TBrio) => Observable<TProject>
) => (source: Observable<Brio<TBrio>>) => Observable<TProject>;
export declare const switchMapBrio: <TBrio, TProject>(
    project: (value: TBrio) => Observable<TProject> | Observable<Brio<TProject>>
) => (source: Observable<Brio<TBrio>>) => Observable<Brio<TProject>>;
export declare const flatCombineLatest: <T>(
    observables: Record<string, Observable<Brio<T>> | Observable<T> | T>
) => Observable<Record<string, T | undefined>>;
export declare const mapBrio: <TBrio, TProject>(
    project: (value: TBrio) => Observable<TProject>
) => (brio: Brio<TBrio>) => Observable<TProject>;
export declare const prepend: <T extends unknown[]>(
    ...values: T
) => <U>(source: Observable<Brio<U>>) => Observable<Brio<U | T>>;
export declare const extend: <T extends unknown[]>(
    ...values: T
) => <U>(source: Observable<Brio<U>>) => Observable<Brio<U | T>>;
export declare const map: <T, U>(
    project: (...args: any[]) => U
) => (source: Observable<Brio<T> | T>) => Observable<Brio<U>>;
export declare const mapBrioBrio: <TBrio, TProject>(
    project: (value: TBrio) => Observable<TProject> | Observable<Brio<TProject>>
) => (brio: Brio<TBrio>) => Observable<Brio<TProject>>;
export declare const toEmitOnDeathObservable: <T, U>(
    brio: Brio<T> | T,
    emitOnDeathValue: U
) => Observable<T | U>;
export declare const mapBrioToEmitOnDeathObservable: <T, U>(
    emitOnDeathValue: U
) => (brio: Brio<T> | T) => Observable<T | U>;
export declare const emitOnDeath: <T, U>(
    emitOnDeathValue: U
) => (source: Observable<Brio<T> | T>) => Observable<T | U>;
export declare const flattenToValueAndNil: <T>(
    source: Observable<Brio<T> | T>
) => Observable<T | undefined>;
export declare const onlyLastBrioSurvives: <T>() => (source: Observable<Brio<T>>) => Observable<Brio<T>>;
export declare const switchToBrio: <T>(
    predicate?: (value: T) => boolean
) => (source: Observable<T | Brio<T>>) => Observable<Brio<T>>;