export interface GroupRankConfigInput {
  groupId: number;
  minAdminRequiredRank: number;
  minCreatorRequiredRank: number;
  remoteFunctionName?: string;
}

export interface GroupRankConfig extends GroupRankConfigInput {
  type: 'GroupRankConfigType';
}

export interface SingleUserConfigInput {
  userId: number;
  remoteFunctionName?: string;
}

export interface SingleUserConfig extends SingleUserConfigInput {
  type: 'SingleUserConfigType';
}

export type PermissionProviderConfig = GroupRankConfig | SingleUserConfig;

export namespace PermissionProviderUtils {
  function createGroupRankConfig(config: GroupRankConfigInput): GroupRankConfig;
  function createSingleUserConfig(
    config: SingleUserConfigInput
  ): SingleUserConfig;
  function createConfigFromGame(): PermissionProviderConfig;
}
