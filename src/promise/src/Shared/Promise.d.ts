import { Maid } from '../../../maid';

type Promise<T extends unknown[] = unknown[]> = {
  Then(
    onFulfilled: (...values: T) => void,
    onRejected?: (error: unknown) => void
  ): Promise<T>;
  Catch(onRejected: (error: unknown) => void): Promise<T>;
  Finally(onFinally: () => void): Promise<T>;
  Tap(
    onFulfilled: (...values: T) => void,
    onRejected?: (error: unknown) => void
  ): Promise<T>;

  Destroy(): void;
};

interface PromiseConstructor {
  readonly ClassName: 'Promise';
  new <T extends unknown[] = unknown[]>(
    func: (
      resolve: (...values: T) => void,
      reject: (error: unknown) => void
    ) => void
  ): Promise<T>;

  isPromise: (value: unknown) => value is Promise<unknown[]>;
}

export const Promise: PromiseConstructor;
