import { Promise } from '@quenty/promise';

export namespace ContentProviderUtils {
  function promisePreload(contentIdList: (Instance | string)[]): Promise;
}
