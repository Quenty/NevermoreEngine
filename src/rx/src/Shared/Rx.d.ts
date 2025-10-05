import { Observable, Operator } from './Observable';
import { MaidTask } from '@quenty/maid';
import { Signal } from '@quenty/signal';
import { CancelToken } from '@quenty/canceltoken';
import { Promise } from '@quenty/promise';

type ToTuple<T> = T extends [unknown, ...unknown[]] ? T : [T];

export type Predicate<T> = (...args: ToTuple<T>) => boolean;

export namespace Rx {
  const EMPTY: Observable;
  const NEVER: Observable;

  function pipe<T, U>(transformers: Array<Operator<T, U>>): Operator<T, U>;

  function of<T extends unknown[]>(...args: T): Observable<T[number]>;
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

  function tap<T, S extends T>(
    onFire?: (...args: ToTuple<S>) => void,
    onError?: (...args: unknown[]) => void,
    onComplete?: (...args: unknown[]) => void
  ): Operator<T, T>;

  function start<T>(callback: () => T): Operator<T, T>;
  function share<T>(): Operator<T, T>;
  function shareReplay<T>(
    bufferSize?: number,
    windowTimeSeconds?: number
  ): Operator<T, T>;
  function cache<T>(): Operator<T, T>;
  function startFrom<T, U>(callback: () => U[]): Operator<T, T | U>;
  function startWith<T, U>(values: U[]): Operator<T, T | U>;
  function scan<T, U>(
    accumulator: (acc: T | undefined, ...args: ToTuple<U>) => T,
    seed?: T
  ): Operator<U, T>;
  function reduce<T, U>(
    reducer: (acc: T | undefined, ...args: ToTuple<U>) => T,
    seed?: T
  ): Operator<U, T>;
  function defaultsTo<T>(value: T): Operator<T, T>;
  function defaultsToNil<T>(source: Observable<T>): Observable<T | undefined>;
  function endWith<T>(...values: ToTuple<T>): Operator<T, T>;

  function where<T>(
    predicate: (value: T) => value is NonNullable<T>
  ): Operator<T, NonNullable<T>>;
  function where<T>(
    predicate: (value: T) => value is Exclude<T, NonNullable<T>>
  ): Operator<T, Exclude<T, NonNullable<T>>>;
  // we cant do a tuple check here so we fallback to any[] (should be ok since not a lot of observables emit tuples)
  function where<T>(predicate: (value: T) => boolean): Operator<T, T>;
  function where<T>(predicate: (...values: any[]) => boolean): Operator<T, T>;

  function distinct<T>(): Operator<T, T>;
  function mapTo<T>(...args: ToTuple<T>): Operator<unknown, T>;
  function map<T, S extends T, U>(project: (...args: ToTuple<S>) => U): Operator<T, U>;
  function mergeAll<T>(): Operator<Observable<T>, T>;
  function switchAll<T>(): Operator<Observable<T>, T>;
  function flatMap<T, U>(
    project: (...args: ToTuple<T>) => Observable<U>
  ): Operator<T, U>;
  function switchMap<T, U>(
    project: (...args: ToTuple<T>) => Observable<U>
  ): Operator<T, U>;
  function takeUntil<T>(notifier: Observable<unknown>): Operator<T, T>;
  function packed<T>(...args: ToTuple<T>): Observable<T>;
  function unpacked<T>(observable: Observable<T[]>): Observable<T>;
  function finalize<T>(finalizerCallback: () => void): Operator<T, T>;
  function combineLatestAll<T>(): (
    source: Observable<Observable<T>>
  ) => Observable<T>;
  function combineAll<T>(source: Observable<Observable<T>>): Observable<T>;
  function catchError<T, E, R>(
    callback: (error: E) => Observable<R>
  ): Operator<T, T | R>;
  function combineLatest<
    T extends Record<string | number | symbol, Observable<unknown> | unknown>
  >(
    observables: T
  ): Observable<{
    [K in keyof T]: T[K] extends Observable<infer V> ? V : T[K];
  }>;
  const combineLatestDefer: typeof combineLatest;
  function defer<T>(observableFactory: () => Observable<T>): Observable<T>;
  function delay<T>(seconds: number): Operator<T, T>;
  function delayed(seconds: number): Observable;
  function timer(
    initialDelaySeconds: number,
    seconds: number
  ): Observable<number[]>;
  function interval(seconds: number): Observable<number[]>;
  function withLatestFrom<T, U>(
    inputObservables: Observable<U>[]
  ): Operator<T, [T, ...ToTuple<U>]>;
  function throttleTime<T>(
    duration: number,
    throttleConfig?: { leading?: boolean; trailing?: boolean }
  ): Operator<T, T>;
  function onlyAfterDefer<T>(): Operator<T, T>;
  function throttleDefer<T>(): Operator<T, T>;
  function throttle<T>(
    durationSelector: (...args: ToTuple<T>) => Observable<unknown>
  ): Operator<T, T>;
  function skipUntil<T>(notifier: Observable<unknown>): Operator<T, T>;
  function skipWhile<T>(
    predicate: (index: number, ...args: ToTuple<T>) => boolean
  ): Operator<T, T>;
  function takeWhile<T>(
    predicate: (index: number, ...args: ToTuple<T>) => boolean
  ): Operator<T, T>;
  function switchScan<T, U>(
    accumulator: (acc: T | undefined, ...args: ToTuple<U>) => Observable<T>,
    seed?: T
  ): Operator<U, T>;
  function mergeScan<T, U>(
    accumulator: (acc: T | undefined, ...args: ToTuple<U>) => Observable<T>,
    seed?: T
  ): Operator<U, T>;
  function using<T>(
    resourceFactory: () => MaidTask,
    observableFactory: (resource: MaidTask) => Observable<T>
  ): Observable<T>;
  function first<T>(): Operator<T, T>;
  function take<T>(count: number): Operator<T, T>;
  function skip<T>(count: number): Operator<T, T>;
}
