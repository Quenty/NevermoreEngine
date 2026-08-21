import { Promise } from '@quenty/promise';

export namespace PlayerThumbnailUtils {
  function promiseUserThumbnail(
    userId: number,
    thumbnailType?: Enum.ThumbnailType,
    thumbnailSize?: Enum.ThumbnailSize
  ): Promise<string>;
  function promiseUserName(userId: number): Promise<string>;
}
