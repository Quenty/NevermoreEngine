import { Maid } from '@quenty/maid';

export namespace RagdollBallSocketUtils {
  function getRigData(rigType: Enum.HumanoidRigType): {
    part0Name: string;
    part1Name: string;
    attachmentName: string;
    motorParentName: string;
    motorName: string;
    limitData: any;
  }[];
  function ensureBallSockets(
    character: Model,
    rigType: Enum.HumanoidRigType
  ): Maid;
}
