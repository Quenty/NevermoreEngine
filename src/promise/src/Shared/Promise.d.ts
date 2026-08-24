type ToTuple<T> = [T] extends [LuaTuple<infer V>] ? V : [T];

type Resolve<T> = (...args: ToTuple<T>) => void;
type Reject = (error: unknown) => void;
type ResolveReject<T> = (resolve: Resolve<T>, reject: Reject) => void;

type Promise<T = void> = {
  Then<R>(
    onFulfilled: (...values: ToTuple<T>) => R,
    onRejected?: (error: unknown) => void
  ): Promise<R>;
  Catch(onRejected: (error: unknown) => void): Promise<T>;
  Finally(onFinally: (...values: ToTuple<T>) => void): Promise<T>;
  Tap(
    onFulfilled: (...values: ToTuple<T>) => void,
    onRejected?: (error: unknown) => void
  ): Promise<T>;

  Destroy(): void;
};

interface PromiseConstructor {
  readonly ClassName: 'Promise';
  new <T>(
    func: (
      resolve: (...values: ToTuple<T>) => void,
      reject: (error: unknown) => void
    ) => void
  ): Promise<T>;

  spawn: <T>(func: ResolveReject<T>) => Promise<T>;
  delay: <T>(seconds: number, func: ResolveReject<T>) => Promise<T>;
  defer: <T>(func: ResolveReject<T>) => Promise<T>;
  resolved: <T>(...values: ToTuple<T>) => Promise<T>;
  rejected: (...args: unknown[]) => Promise;

  isPromise: (value: unknown) => value is Promise<unknown>;
}

export const Promise: PromiseConstructor;
