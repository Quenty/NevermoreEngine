import { Observable } from './Observable';
import { MaidTask } from '../../../maid';

export type Predicate<T extends unknown[] = unknown[]> = (
  ...args: T
) => boolean;

export const EMPTY: Observable<[]>;
export const NEVER: Observable<[]>;

export function pipe<T extends unknown[], U extends unknown[]>(
  transformers: Array<(source: Observable<T>) => Observable<U>>
): (source: Observable<T>) => Observable<U>;

export function of<T extends unknown[]>(...args: T): Observable<T>;
export function failed<T extends unknown[]>(...args: T): Observable<T>;
export function from<T extends unknown[]>(
  item: Promise<T> | T[] | any
): Observable<T>;
export function toPromise<T extends unknown[]>(
  observable: Observable<T>,
  cancelToken?: any
): Promise<T>;
export function merge<T extends unknown[]>(
  observables: Array<Observable<T>>
): Observable<T>;
export function fromSignal<T extends unknown[]>(
  event: RBXScriptSignal | { Connect: (cb: (...args: T) => void) => any }
): Observable<T>;
export function fromPromise<T extends unknown[]>(
  promise: Promise<T>
): Observable<T>;

export function tap<T extends unknown[]>(
  onFire?: (...args: T) => void,
  onError?: (...args: unknown[]) => void,
  onComplete?: (...args: unknown[]) => void
): (source: Observable<T>) => Observable<T>;

export function start<T extends unknown[]>(
  callback: () => T
): (source: Observable<T>) => Observable<T>;
export function share<T extends unknown[]>(): (
  source: Observable<T>
) => Observable<T>;
export function shareReplay<T extends unknown[]>(
  bufferSize?: number,
  windowTimeSeconds?: number
): (source: Observable<T>) => Observable<T>;
export function cache<T extends unknown[]>(): (
  source: Observable<T>
) => Observable<T>;
export function startFrom<T extends unknown[], U extends unknown[]>(
  callback: () => U[]
): (source: Observable<T>) => Observable<U | T>;
export function startWith<T extends unknown[], U extends unknown[]>(
  values: U[]
): (source: Observable<T>) => Observable<T | U>;
export function scan<T extends unknown[], U extends unknown[]>(
  accumulator: (acc: T | undefined, ...args: U) => T,
  seed?: T
): (source: Observable<U>) => Observable<T>;
export function reduce<T extends unknown[], U extends unknown[]>(
  reducer: (acc: T | undefined, ...args: U) => T,
  seed?: T
): (source: Observable<U>) => Observable<T>;
export function defaultsTo<T extends unknown[]>(
  value: T
): (source: Observable<T>) => Observable<T>;
export function defaultsToNil<T extends unknown[]>(
  source: Observable<T>
): Observable<T | [undefined]>;
export function endWith<T extends unknown[]>(
  ...values: T
): (source: Observable<T>) => Observable<T>;
export function where<T extends unknown[]>(
  predicate: Predicate<T>
): (source: Observable<T>) => Observable<T>;
export function distinct<T extends unknown[]>(): (
  source: Observable<T>
) => Observable<T>;
export function mapTo<T extends unknown[]>(
  ...args: T
): (source: Observable<any>) => Observable<T>;
export function map<T extends unknown[], U extends unknown[]>(
  project: (...args: T) => U
): (source: Observable<T>) => Observable<U>;
export function mergeAll<T extends unknown[]>(): (
  source: Observable<[Observable<T>]>
) => Observable<T>;
export function switchAll<T extends unknown[]>(): (
  source: Observable<[Observable<T>]>
) => Observable<T>;
export function flatMap<T extends unknown[], U extends unknown[]>(
  project: (...args: T) => Observable<U>
): (source: Observable<T>) => Observable<U>;
export function switchMap<T extends unknown[], U extends unknown[]>(
  project: (...args: T) => Observable<U>
): (source: Observable<T>) => Observable<U>;
export function takeUntil<T extends unknown[]>(
  notifier: Observable<any>
): (source: Observable<T>) => Observable<T>;
export function packed<T extends unknown[]>(...args: T): Observable<T>;
export function unpacked<T extends unknown[]>(
  observable: Observable<T[]>
): Observable<T>;
export function finalize<T extends unknown[]>(
  finalizerCallback: () => void
): (source: Observable<T>) => Observable<T>;
export function combineLatestAll<T extends unknown[]>(): (
  source: Observable<[Observable<T>]>
) => Observable<T>;
export function combineAll<T extends unknown[]>(
  source: Observable<[Observable<T>]>
): Observable<T>;
export function catchError<T extends unknown[], E, R extends unknown[]>(
  callback: (error: E) => Observable<R>
): (source: Observable<T>) => Observable<T | R>;
export function combineLatest<
  K extends string | number | symbol,
  V extends unknown[]
>(observables: Record<K, Observable<V> | V>): Observable<[Record<K, V>]>;
export function combineLatestDefer<
  K extends string | number | symbol,
  V extends unknown[]
>(observables: Record<K, Observable<V> | V>): Observable<[Record<K, V>]>;
export function defer<T extends unknown[]>(
  observableFactory: () => Observable<T>
): Observable<T>;
export function delay<T extends unknown[]>(
  seconds: number
): (source: Observable<T>) => Observable<T>;
export function delayed(seconds: number): Observable<[]>;
export function timer(
  initialDelaySeconds: number,
  seconds: number
): Observable<number[]>;
export function interval(seconds: number): Observable<number[]>;
export function withLatestFrom<T extends unknown[], U extends unknown[]>(
  inputObservables: Array<Observable<U>>
): (source: Observable<T>) => Observable<[T, ...U]>;
export function throttleTime<T extends unknown[]>(
  duration: number,
  throttleConfig?: { leading?: boolean; trailing?: boolean }
): (source: Observable<T>) => Observable<T>;
export function onlyAfterDefer<T extends unknown[]>(): (
  source: Observable<T>
) => Observable<T>;
export function throttleDefer<T extends unknown[]>(): (
  source: Observable<T>
) => Observable<T>;
export function throttle<T extends unknown[]>(
  durationSelector: (...args: T) => Observable<any>
): (source: Observable<T>) => Observable<T>;
export function skipUntil<T extends unknown[]>(
  notifier: Observable<any>
): (source: Observable<T>) => Observable<T>;
export function skipWhile<T extends unknown[]>(
  predicate: (index: number, ...args: T) => boolean
): (source: Observable<T>) => Observable<T>;
export function takeWhile<T extends unknown[]>(
  predicate: (index: number, ...args: T) => boolean
): (source: Observable<T>) => Observable<T>;
export function switchScan<T extends unknown[], U extends unknown[]>(
  accumulator: (acc: T | undefined, ...args: U) => Observable<T>,
  seed?: T
): (source: Observable<U>) => Observable<T>;
export function mergeScan<T extends unknown[], U extends unknown[]>(
  accumulator: (acc: T | undefined, ...args: U) => Observable<T>,
  seed?: T
): (source: Observable<U>) => Observable<T>;
export function using<T extends unknown[]>(
  resourceFactory: () => MaidTask,
  observableFactory: (resource: MaidTask) => Observable<T>
): Observable<T>;
export function first<T extends unknown[]>(): (
  source: Observable<T>
) => Observable<T>;
export function take<T extends unknown[]>(
  count: number
): (source: Observable<T>) => Observable<T>;
export function skip<T extends unknown[]>(
  count: number
): (source: Observable<T>) => Observable<T>;
