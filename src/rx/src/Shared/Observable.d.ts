import { MaidTask } from '../../../maid';
import { Subscription } from './Subscription';

type Observable<T = void> = {
  // we type out the Pipe method using varargs instead of an array of operators.
  // this is because typescript cannot infer types from operator to operator (this is a typescript limitation)
  // however, typescript can infer types using the overloads below. this is also how rxjs does it.
  // our fork of roblox-ts will convert the outputted luau to use an array of operators.
  Pipe(): Observable<T>;
  Pipe<A>(op1: Operator<T, A>): Observable<A>;
  Pipe<A, B>(op1: Operator<T, A>, op2: Operator<A, B>): Observable<B>;
  Pipe<A, B, C>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>
  ): Observable<C>;
  Pipe<A, B, C, D>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>,
    op4: Operator<C, D>
  ): Observable<D>;
  Pipe<A, B, C, D, E>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>,
    op4: Operator<C, D>,
    op5: Operator<D, E>
  ): Observable<E>;
  Pipe<A, B, C, D, E, F>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>,
    op4: Operator<C, D>,
    op5: Operator<D, E>,
    op6: Operator<E, F>
  ): Observable<F>;
  Pipe<A, B, C, D, E, F, G>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>,
    op4: Operator<C, D>,
    op5: Operator<D, E>,
    op6: Operator<E, F>,
    op7: Operator<F, G>
  ): Observable<G>;
  Pipe<A, B, C, D, E, F, G, H>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>,
    op4: Operator<C, D>,
    op5: Operator<D, E>,
    op6: Operator<E, F>,
    op7: Operator<F, G>,
    op8: Operator<G, H>
  ): Observable<H>;
  Pipe<A, B, C, D, E, F, G, H, I>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>,
    op4: Operator<C, D>,
    op5: Operator<D, E>,
    op6: Operator<E, F>,
    op7: Operator<F, G>,
    op8: Operator<G, H>,
    op9: Operator<H, I>
  ): Observable<I>;
  Pipe<A, B, C, D, E, F, G, H, I, J>(
    op1: Operator<T, A>,
    op2: Operator<A, B>,
    op3: Operator<B, C>,
    op4: Operator<C, D>,
    op5: Operator<D, E>,
    op6: Operator<E, F>,
    op7: Operator<F, G>,
    op8: Operator<G, H>,
    op9: Operator<H, I>,
    op10: Operator<I, J>
  ): Observable<J>;
  Pipe(...operators: Operator<unknown, unknown>[]): Observable<unknown>;
  // tuple wrap to prevent distributive conditional types
  Subscribe(
    fireCallback?: [T] extends [unknown[]]
      ? (...args: T) => void
      : (value: T) => void,
    failCallback?: () => void,
    completeCallback?: () => void
  ): Subscription<T>;
  // overload for unresolved generic
  Subscribe(
    fireCallback?: (value: T) => void,
    failCallback?: () => void,
    completeCallback?: () => void
  ): Subscription<T>;
};

export type Operator<In, Out> = (source: Observable<In>) => Observable<Out>;

interface ObservableConstructor {
  readonly ClassName: 'Observable';
  new <T>(
    onSubscribe: (subscription: Subscription<T>) => MaidTask
  ): Observable<T>;

  isObservable: (value: unknown) => value is Observable<unknown>;
}

export const Observable: ObservableConstructor;
