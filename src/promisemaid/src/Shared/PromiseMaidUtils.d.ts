import { Maid } from '@quenty/maid';

export namespace PromiseMaidUtils {
  function whilePromise<T>(
    promise: Promise<T>,
    callback: (maid: Maid) => void
  ): Maid;
}
