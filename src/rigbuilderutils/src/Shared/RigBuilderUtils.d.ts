import { Promise } from '@quenty/promise';

export namespace RigBuilderUtils {
  function disableAnimateScript(rig: Model): void;
  function findAnimateScript(rig: Model): LocalScript | Script | undefined;
  function createR6BaseRig(): Model;
  function createR6MeshRig(): Model;
  function createR6MeshBoyRig(): Model;
  function createR6MeshGirlRig(): Model;
  function promiseR15PackageRig(packageAssetId: number): Promise<Model>;
  function promiseR15Rig(): Promise<Model>;
  function promiseR15ManRig(): Promise<Model>;
  function promiseR15WomanRig(): Promise<Model>;
  function promiseR15MeshRig(): Promise<Model>;
  function promiseBasePlayerRig(
    userId: number,
    humanoidRigType?: Enum.HumanoidRigType,
    assetTypeVerification?: Enum.AssetTypeVerification
  ): Promise<Model>;
  function promiseHumanoidModelFromDescription(
    description: HumanoidDescription,
    rigType?: Enum.HumanoidRigType,
    assetTypeVerification?: Enum.AssetTypeVerification
  ): Promise<Model>;
  function promiseHumanoidModelFromUserId(
    userId: number,
    rigType?: Enum.HumanoidRigType,
    assetTypeVerification?: Enum.AssetTypeVerification
  ): Promise<Model>;
  function promisePlayerRig(userId: number): Promise<Model>;
}
