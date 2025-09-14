export namespace RbxAssetUtils {
  function toRbxAssetId(id: string | number): string;
  function isConvertableToRbxAsset(
    id: string | number | undefined
  ): id is string | number;
}
