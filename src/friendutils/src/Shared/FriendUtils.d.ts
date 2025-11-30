import { Promise } from '@quenty/promise';

interface FriendData {
  AvatarFinal: boolean;
  AvatarUri: string;
  Id: number;
  Username: string;
  IsOnline: boolean;
}

export namespace FriendUtils {
  function promiseAllStudioFriends(): Promise<FriendData[]>;
  function onlineFriends(friends: FriendData[]): FriendData[];
  function friendsNotInGame(friends: FriendData[]): FriendData[];
  function promiseAllFriends(
    userId: number,
    limitMaxFriends?: number
  ): Promise<FriendData[]>;
  function promiseFriendPages(userId: number): Promise<FriendPages>;
  function iterateFriendsYielding(
    pages: FriendPages
  ): IterableIterator<FriendData>;
  function promiseStudioServiceUserId(): Promise<number>;
  function promiseCurrentStudioUserId(): Promise<number>;
}
