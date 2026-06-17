import { Promise } from '@quenty/promise';

interface RoleInfo {
  Name: string;
  Rank: number;
}

export namespace GroupUtils {
  function promiseRankInGroup(player: Player, groupId: number): Promise<number>;
  function promiseRoleInGroup(player: Player, groupId: number): Promise<string>;
  function promiseGroupInfo(groupId: number): Promise<GroupInfo>;
  function promiseGroupRoleInfo(
    groupId: number,
    rankId: number
  ): Promise<RoleInfo>;
}
