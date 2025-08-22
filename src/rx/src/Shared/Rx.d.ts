import { Observable } from './Observable';
import { MaidTask } from '../../../maid';
import { Signal } from '../../../signal/src/Shared/Signal';
import { CancelToken } from '../../../canceltoken';

export type Predicate<T> = (...args: T extends unknown[] ? T : [T]) => boolean;
type ToTuple<T> = T extends unknown[] ? T : [T];

export namespace Rx {
  const EMPTY: Observable;
  const NEVER: Observable;

  function pipe<T, U>(
    transformers: Array<(source: Observable<T>) => Observable<U>>
  ): (source: Observable<T>) => Observable<U>;

  function of<T>(...args: ToTuple<T>): Observable<T>;
  function failed<T>(...args: ToTuple<T>): Observable<T>;
  function from<T>(item: Promise<T> | T[]): Observable<T>;
  function toPromise<T>(
    observable: Observable<T>,
    cancelToken?: CancelToken
  ): Promise<T>;
  function merge<T>(observables: Observable<T>[]): Observable<T>;
  function fromSignal<T>(
    event:
      | Signal<T>
      | { Connect: (cb: (...args: ToTuple<T>) => void) => unknown }
  ): Observable<T>;
  function fromPromise<T>(promise: Promise<T>): Observable<T>;

  function tap<T>(
    onFire?: (...args: ToTuple<T>) => void,
    onError?: (...args: unknown[]) => void,
    onComplete?: (...args: unknown[]) => void
  ): (source: Observable<T>) => Observable<T>;

  function start<T>(
    callback: () => T
  ): (source: Observable<T>) => Observable<T>;
  function share<T>(): (source: Observable<T>) => Observable<T>;
  function shareReplay<T>(
    bufferSize?: number,
    windowTimeSeconds?: number
  ): (source: Observable<T>) => Observable<T>;
  function cache<T>(): (source: Observable<T>) => Observable<T>;
  function startFrom<T, U>(
    callback: () => U[]
  ): (source: Observable<T>) => Observable<U | T>;
  function startWith<T, U>(
    values: U[]
  ): (source: Observable<T>) => Observable<T | U>;
  function scan<T, U>(
    accumulator: (acc: T | undefined, ...args: ToTuple<U>) => T,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function reduce<T, U>(
    reducer: (acc: T | undefined, ...args: ToTuple<U>) => T,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function defaultsTo<T>(value: T): (source: Observable<T>) => Observable<T>;
  function defaultsToNil<T>(source: Observable<T>): Observable<T | [undefined]>;
  function endWith<T>(
    ...values: ToTuple<T>
  ): (source: Observable<T>) => Observable<T>;
  function where<T>(
    predicate: Predicate<T>
  ): (source: Observable<T>) => Observable<T>;
  function distinct<T>(): (source: Observable<T>) => Observable<T>;
  function mapTo<T>(
    ...args: ToTuple<T>
  ): (source: Observable<unknown>) => Observable<T>;
  function map<T, U>(
    project: (...args: ToTuple<T>) => U
  ): (source: Observable<T>) => Observable<U>;
  function mergeAll<T>(): (source: Observable<Observable<T>>) => Observable<T>;
  function switchAll<T>(): (source: Observable<Observable<T>>) => Observable<T>;
  function flatMap<T, U>(
    project: (...args: ToTuple<T>) => Observable<U>
  ): (source: Observable<T>) => Observable<U>;
  function switchMap<T, U>(
    project: (...args: ToTuple<T>) => Observable<U>
  ): (source: Observable<T>) => Observable<U>;
  function takeUntil<T>(
    notifier: Observable<unknown>
  ): (source: Observable<T>) => Observable<T>;
  function packed<T>(...args: ToTuple<T>): Observable<T>;
  function unpacked<T>(observable: Observable<T[]>): Observable<T>;
  function finalize<T>(
    finalizerCallback: () => void
  ): (source: Observable<T>) => Observable<T>;
  function combineLatestAll<T>(): (
    source: Observable<Observable<T>>
  ) => Observable<T>;
  function combineAll<T>(source: Observable<Observable<T>>): Observable<T>;
  function catchError<T, E, R>(
    callback: (error: E) => Observable<R>
  ): (source: Observable<T>) => Observable<T | R>;
  function combineLatest<K extends string | number | symbol, V>(
    observables: Record<K, Observable<V> | V>
  ): Observable<Record<K, V>>;
  function combineLatestDefer<K extends string | number | symbol, V>(
    observables: Record<K, Observable<V> | V>
  ): Observable<Record<K, V>>;
  function defer<T>(observableFactory: () => Observable<T>): Observable<T>;
  function delay<T>(seconds: number): (source: Observable<T>) => Observable<T>;
  function delayed(seconds: number): Observable;
  function timer(
    initialDelaySeconds: number,
    seconds: number
  ): Observable<number[]>;
  function interval(seconds: number): Observable<number[]>;
  function withLatestFrom<T, U>(
    inputObservables: Observable<U>[]
  ): (source: Observable<T>) => Observable<[T, ...ToTuple<U>]>;
  function throttleTime<T>(
    duration: number,
    throttleConfig?: { leading?: boolean; trailing?: boolean }
  ): (source: Observable<T>) => Observable<T>;
  function onlyAfterDefer<T>(): (source: Observable<T>) => Observable<T>;
  function throttleDefer<T>(): (source: Observable<T>) => Observable<T>;
  function throttle<T>(
    durationSelector: (...args: ToTuple<T>) => Observable<unknown>
  ): (source: Observable<T>) => Observable<T>;
  function skipUntil<T>(
    notifier: Observable<unknown>
  ): (source: Observable<T>) => Observable<T>;
  function skipWhile<T>(
    predicate: (index: number, ...args: ToTuple<T>) => boolean
  ): (source: Observable<T>) => Observable<T>;
  function takeWhile<T>(
    predicate: (index: number, ...args: ToTuple<T>) => boolean
  ): (source: Observable<T>) => Observable<T>;
  function switchScan<T, U>(
    accumulator: (acc: T | undefined, ...args: ToTuple<U>) => Observable<T>,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function mergeScan<T, U>(
    accumulator: (acc: T | undefined, ...args: ToTuple<U>) => Observable<T>,
    seed?: T
  ): (source: Observable<U>) => Observable<T>;
  function using<T>(
    resourceFactory: () => MaidTask,
    observableFactory: (resource: MaidTask) => Observable<T>
  ): Observable<T>;
  function first<T>(): (source: Observable<T>) => Observable<T>;
  function take<T>(count: number): (source: Observable<T>) => Observable<T>;
  function skip<T>(count: number): (source: Observable<T>) => Observable<T>;
}
