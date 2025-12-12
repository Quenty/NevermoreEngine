import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';

export namespace PromiseMaidUtils {
  function whilePromise<T>(
    promise: Promise<T>,
    callback: (maid: Maid) => void
  ): Maid;
}
