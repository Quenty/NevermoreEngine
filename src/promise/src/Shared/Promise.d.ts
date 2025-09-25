type ToTuple<T> = T extends unknown[] ? T : [T];

type Promise<T = void> = {
  Then<R>(
    onFulfilled: (...values: ToTuple<T>) => R,
    onRejected?: (error: unknown) => void
  ): Promise<R>;
  Catch(onRejected: (error: unknown) => void): Promise<T>;
  Finally(onFinally: () => void): Promise<T>;
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

  isPromise: (value: unknown) => value is Promise<unknown>;
}

export const Promise: PromiseConstructor;
