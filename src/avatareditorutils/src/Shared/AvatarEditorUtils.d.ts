import { Promise } from '@quenty/promise';

export type ToItemDetails<T extends Enum.AvatarItemType> =
  T extends Enum.AvatarItemType.Asset
    ? AssetItemDetails
    : T extends Enum.AvatarItemType.Bundle
    ? BundleItemDetails
    : ItemDetails;

export namespace AvatarEditorUtils {
  function promiseItemDetails<T extends Enum.AvatarItemType>(
    itemId: number,
    itemType: T
  ): Promise<ToItemDetails<T>>;
  function promiseBatchItemDetails<T extends Enum.AvatarItemType>(
    itemIds: number[],
    itemType: T
  ): Promise<ToItemDetails<T>[]>;
  function promiseCheckApplyDefaultClothing(
    humanoidDescription: HumanoidDescription
  ): Promise<HumanoidDescription | undefined>;
  function promiseConformToAvatarRules(
    humanoidDescription: HumanoidDescription
  ): Promise<HumanoidDescription>;
  function promiseAvatarRules(): Promise<AvatarRules>;
  function promiseIsFavorited(
    itemId: number,
    itemType: Enum.AvatarItemType
  ): Promise<boolean>;
  function promiseSearchCatalog(
    catalogSearchParams: CatalogSearchParams
  ): Promise<CatalogPages>;
  function promiseInventoryPages(
    assetTypes: Enum.AvatarAssetType[]
  ): Promise<InventoryPages>;
  function promiseOutfitPages(
    outfitSource: Enum.OutfitSource,
    outfitType: Enum.OutfitType
  ): Promise<OutfitPages>;
  function promiseRecommendedAssets(
    assetType: Enum.AvatarAssetType,
    contextAssetId?: number
  ): Promise<RecommendedAsset[]>;
  function promiseRecommendedBundles(
    bundleId: number
  ): Promise<RecommendedBundle[]>;
  function promptAllowInventoryReadAccess(): Promise<Enum.AvatarPromptResult>;
  function promptCreateOutfit(
    outfit: HumanoidDescription,
    rigType: Enum.HumanoidRigType
  ): Promise<Enum.AvatarPromptResult>;
  function promptDeleteOutfit(
    outfitId: number
  ): Promise<Enum.AvatarPromptResult>;
  function promptRenameOutfit(
    outfitId: number
  ): Promise<Enum.AvatarPromptResult>;
  function promptSaveAvatar(
    humanoidDescription: HumanoidDescription,
    rigType: Enum.HumanoidRigType
  ): Promise<Enum.AvatarPromptResult>;
  function promptSetFavorite(
    itemId: number,
    itemType: Enum.AvatarItemType,
    shouldFavorite: boolean
  ): Promise<Enum.AvatarPromptResult>;
  function promptUpdateOutfit(
    outfitId: number,
    updatedOutfit: HumanoidDescription,
    rigType: Enum.HumanoidRigType
  ): Promise<Enum.AvatarPromptResult>;
}
