export namespace AccessoryTypeUtils {
  function tryGetAccessoryType(
    avatarAssetType: Enumerator.AvatarAssetType
  ): LuaTuple<[accessoryType?: Enum.accessoryType, err?: string]>;
  function getAccessoryTypeFromName(accessoryType: string): Enum.accessoryType;
  function convertAssetTypeIdToAssetType(
    assetTypeId: number
  ): Enum.AssetType | undefined;
  function convertAssetTypeIdToAvatarAssetType(
    avatarAssetTypeId: number
  ): Enum.AvatarAssetType | undefined;
}
