import { RbxThumbnailTypes } from './RbxThumbnailTypes';

export namespace RbxThumbUtils {
  function getThumbnailUrl(
    thumbnailType: (typeof RbxThumbnailTypes)[keyof typeof RbxThumbnailTypes],
    targetId: number,
    width: number,
    height: number
  ): string;
  function avatarItemTypeToThumbnailType(
    avatarItemType: Enum.AvatarItemType
  ): 'Asset' | 'BundleThumbnail';
  function getAssetThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getAvatarThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getAvatarHeadShotThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getBadgeIconThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getBundleThumbnailThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getGameIconThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getGamePassThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getGroupIconThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
  function getOutfitThumbnailUrl(
    targetId: number,
    width?: number,
    height?: number
  ): string;
}
