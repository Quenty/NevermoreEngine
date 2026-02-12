import { Signal } from '@quenty/signal';
import { Promise } from './Promise';

export namespace PromiseUtils {
  function any<T>(promises: Promise<T>[]): Promise<T>;
  function delayed(seconds: number): Promise;
  function all<T>(promises: Promise<T>[]): Promise<T[]>;
  function firstSuccessOrLastFailure<T>(promises: Promise<T>[]): Promise<T>;
  function combine<K, V>(promises: Map<K, Promise<V>>): Promise<Map<K, V>>;
  function invert<T>(promise: Promise<T>): Promise<T>;
  function fromSignal<T>(signal: Signal<T>): Promise<T>;
  function timeout<T>(timeoutTime: number, fromPromise: Promise<T>): Promise<T>;
}
