import { Maid } from '@quenty/maid';

export namespace RagdollAdditionalAttachmentUtils {
  function getAdditionalAttachmentData(
    rigType: Enum.HumanoidRigType
  ): [
    limbName: string,
    attachmentName: string,
    cframe: CFrame,
    otherAttachmentName?: string
  ][];
  function ensureAdditionalAttachments(
    character: Model,
    rigType: Enum.HumanoidRigType
  ): Maid;
}
