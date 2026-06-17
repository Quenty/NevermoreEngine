import { Promise } from '@quenty/promise';

export namespace HumanoidDescriptionUtils {
  function promiseApplyDescription(
    humanoid: Humanoid,
    description: HumanoidDescription
  ): Promise;
  function promiseApplyDescriptionReset(
    humanoid: Humanoid,
    description: HumanoidDescription,
    assetTypeVerification?: Enum.AssetTypeVerification
  ): Promise;
  function promiseApplyFromUserName(
    humanoid: Humanoid,
    userName: string
  ): Promise;
  function promiseFromUserName(userName: string): Promise<HumanoidDescription>;
  function promiseFromUserId(userId: number): Promise<HumanoidDescription>;
  function getAssetIdsFromString(assetString: string): number[];
  function getAssetPromisesFromString(assetString: string): Promise<Instance>[];
}
