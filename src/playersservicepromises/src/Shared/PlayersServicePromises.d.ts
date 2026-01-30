import { Promise } from '@quenty/promise';

export namespace PlayersServicePromises {
  function promiseUserIdFromName(name: string): Promise<number>;
}
