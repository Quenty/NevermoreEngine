export namespace AccessoryTypeUtils {
  function tryGetAccessoryType(
    avatarAssetType: Enum.AvatarAssetType
  ): LuaTuple<[accessoryType?: Enum.AccessoryType, err?: string]>;
  function getAccessoryTypeFromName(accessoryType: string): Enum.AccessoryType;
  function convertAssetTypeIdToAssetType(
    assetTypeId: number
  ): Enum.AssetType | undefined;
  function convertAssetTypeIdToAvatarAssetType(
    avatarAssetTypeId: number
  ): Enum.AvatarAssetType | undefined;
}
