import { Promise } from './Promise';

export namespace PromiseRetryUtils {
  function retry<T>(
    callback: () => Promise<T>,
    options: {
      initialWaitTime: number;
      maxAttempts: number;
      printWarning: boolean;
    }
  ): Promise<T>;
}
