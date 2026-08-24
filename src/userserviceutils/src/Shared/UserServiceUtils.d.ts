import { Promise } from '@quenty/promise';

export namespace UserServiceUtils {
  function promiseUserInfosByUserIds(userIds: number[]): Promise<UserInfo[]>;
  function promiseUserInfo(userId: number): Promise<UserInfo>;
  function promiseDisplayName(userId: number): Promise<string>;
  function promiseUserName(userId: number): Promise<string>;
}
