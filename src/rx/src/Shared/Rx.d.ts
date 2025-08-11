import { Observable } from './Observable';
import { MaidTask } from '../../../maid';

export type Predicate<T extends unknown[] = unknown[]> = (
  ...args: T
) => boolean;

export namespace Rx {
  const EMPTY: Observable<[]>;
  const NEVER: Observable<[]>;

  function pipe<T extends unknown[], U extends unknown[]>(
    transformers: Array<(source: Observable<T>) => Observable<U>>
  ): (source: Observable<T>) => Observable<U>;

  function of<T extends unknown[]>(...args: T): Observable<T>;
  function failed<T extends unknown[]>(...args: T): Observable<T>;
  function from<T extends unknown[]>(
    item: Promise<T> | T[] | any
  ): Observable<T>;
  function toPromise<T extends unknown[]>(
    observable: Observable<T>,
    cancelToken?: any
  ): Promise<T>;
  function merge<T extends unknown[]>(
    observables: Array<Observable<T>>
  ): Observable<T>;
  function fromSignal<T extends unknown[]>(
    event: RBXScriptSignal | { Connect: (cb: (...args: T) => void) => any }
  ): Observable<T>;
  function fromPromise<T extends unknown[]>(promise: Promise<T>): Observable<T>;

  function tap<T extends unknown[]>(
    onFire?: (...args: T) => void,
    onError?: (...args: unknown[]) => void,
    onComplete?: (...args: unknown[]) => void
  ): (source: Observable<T>) => Observable<T>;

  function start<T extends unknown[]>(
    callback: () => T
  ): (source: Observable<T>) => Observable<T>;
  function share<T extends unknown[]>(): (
    source: Observable<T>
  ) => Observable<T>;
  function shareReplay<T extends unknown[]>(
    bufferSize?: number,
    windowTimeSeconds?: number
  ): (source: Observable<T>) => Observable<T>;
  function cache<T extends unknown[]>(): (
    source: Observable<T>
  ) => Observable<T>;
  function startFrom<T extends unknown[], U extends unknown[]>(
    callback: () => U[]
  ): (source: Observable<T>) => Observable<U | T>;
  function startWith<T extends unknown[], U extends unknown[]>(
    values: U[]
  ): (source: Observable<T>) => Observable<T | U>;
  function scan<T extends unknown[], U extends unknown[]>(
    accumulator: (acc: T | undefined, ...args: U) => T,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function reduce<T extends unknown[], U extends unknown[]>(
    reducer: (acc: T | undefined, ...args: U) => T,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function defaultsTo<T extends unknown[]>(
    value: T
  ): (source: Observable<T>) => Observable<T>;
  function defaultsToNil<T extends unknown[]>(
    source: Observable<T>
  ): Observable<T | [undefined]>;
  function endWith<T extends unknown[]>(
    ...values: T
  ): (source: Observable<T>) => Observable<T>;
  function where<T extends unknown[]>(
    predicate: Predicate<T>
  ): (source: Observable<T>) => Observable<T>;
  function distinct<T extends unknown[]>(): (
    source: Observable<T>
  ) => Observable<T>;
  function mapTo<T extends unknown[]>(
    ...args: T
  ): (source: Observable<any>) => Observable<T>;
  function map<T extends unknown[], U extends unknown[]>(
    project: (...args: T) => U
  ): (source: Observable<T>) => Observable<U>;
  function mergeAll<T extends unknown[]>(): (
    source: Observable<[Observable<T>]>
  ) => Observable<T>;
  function switchAll<T extends unknown[]>(): (
    source: Observable<[Observable<T>]>
  ) => Observable<T>;
  function flatMap<T extends unknown[], U extends unknown[]>(
    project: (...args: T) => Observable<U>
  ): (source: Observable<T>) => Observable<U>;
  function switchMap<T extends unknown[], U extends unknown[]>(
    project: (...args: T) => Observable<U>
  ): (source: Observable<T>) => Observable<U>;
  function takeUntil<T extends unknown[]>(
    notifier: Observable<any>
  ): (source: Observable<T>) => Observable<T>;
  function packed<T extends unknown[]>(...args: T): Observable<T>;
  function unpacked<T extends unknown[]>(
    observable: Observable<T[]>
  ): Observable<T>;
  function finalize<T extends unknown[]>(
    finalizerCallback: () => void
  ): (source: Observable<T>) => Observable<T>;
  function combineLatestAll<T extends unknown[]>(): (
    source: Observable<[Observable<T>]>
  ) => Observable<T>;
  function combineAll<T extends unknown[]>(
    source: Observable<[Observable<T>]>
  ): Observable<T>;
  function catchError<T extends unknown[], E, R extends unknown[]>(
    callback: (error: E) => Observable<R>
  ): (source: Observable<T>) => Observable<T | R>;
  function combineLatest<
    K extends string | number | symbol,
    V extends unknown[]
  >(observables: Record<K, Observable<V> | V>): Observable<[Record<K, V>]>;
  function combineLatestDefer<
    K extends string | number | symbol,
    V extends unknown[]
  >(observables: Record<K, Observable<V> | V>): Observable<[Record<K, V>]>;
  function defer<T extends unknown[]>(
    observableFactory: () => Observable<T>
  ): Observable<T>;
  function delay<T extends unknown[]>(
    seconds: number
  ): (source: Observable<T>) => Observable<T>;
  function delayed(seconds: number): Observable<[]>;
  function timer(
    initialDelaySeconds: number,
    seconds: number
  ): Observable<number[]>;
  function interval(seconds: number): Observable<number[]>;
  function withLatestFrom<T extends unknown[], U extends unknown[]>(
    inputObservables: Array<Observable<U>>
  ): (source: Observable<T>) => Observable<[T, ...U]>;
  function throttleTime<T extends unknown[]>(
    duration: number,
    throttleConfig?: { leading?: boolean; trailing?: boolean }
  ): (source: Observable<T>) => Observable<T>;
  function onlyAfterDefer<T extends unknown[]>(): (
    source: Observable<T>
  ) => Observable<T>;
  function throttleDefer<T extends unknown[]>(): (
    source: Observable<T>
  ) => Observable<T>;
  function throttle<T extends unknown[]>(
    durationSelector: (...args: T) => Observable<any>
  ): (source: Observable<T>) => Observable<T>;
  function skipUntil<T extends unknown[]>(
    notifier: Observable<any>
  ): (source: Observable<T>) => Observable<T>;
  function skipWhile<T extends unknown[]>(
    predicate: (index: number, ...args: T) => boolean
  ): (source: Observable<T>) => Observable<T>;
  function takeWhile<T extends unknown[]>(
    predicate: (index: number, ...args: T) => boolean
  ): (source: Observable<T>) => Observable<T>;
  function switchScan<T extends unknown[], U extends unknown[]>(
    accumulator: (acc: T | undefined, ...args: U) => Observable<T>,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function mergeScan<T extends unknown[], U extends unknown[]>(
    accumulator: (acc: T | undefined, ...args: U) => Observable<T>,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function using<T extends unknown[]>(
    resourceFactory: () => MaidTask,
    observableFactory: (resource: MaidTask) => Observable<T>
  ): Observable<T>;
  function first<T extends unknown[]>(): (
    source: Observable<T>
  ) => Observable<T>;
  function take<T extends unknown[]>(
    count: number
  ): (source: Observable<T>) => Observable<T>;
  function skip<T extends unknown[]>(
    count: number
  ): (source: Observable<T>) => Observable<T>;
}
