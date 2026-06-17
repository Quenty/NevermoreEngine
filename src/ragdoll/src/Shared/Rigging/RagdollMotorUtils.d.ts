import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';

type MotorData = {
  partName: string;
  motorNam: string;
  isRootJoint?: boolean;
};

export namespace RagdollMotorUtils {
  function getFirstRootJointData(rigType: Enum.HumanoidRigType): MotorData;
  function getMotorData(rigType: Enum.HumanoidRigType): MotorData[];
  function initMotorAttributes(
    character: Model,
    rigType: Enum.HumanoidRigType
  ): void;
  function setupAnimatedMotor(character: Model, part: BasePart): Maid;
  function setupRagdollRootPartMotor(
    motor: Motor6D,
    part0: BasePart,
    part1: BasePart
  ): Maid;
  function setupRagdollMotor(
    motor: Motor6D,
    part0: BasePart,
    part1: BasePart
  ): Maid;
  function suppressJustRootPart(
    character: Model,
    rigType: Enum.HumanoidRigType
  ): Maid;
  function suppressMotors(
    character: Model,
    rigType: Enum.HumanoidRigType
  ): Maid;
  function guessIfNetworkOwner(part: BasePart): boolean;
  function promiseVelocityRecordings(
    character: Model,
    rigType: Enum.HumanoidRigType
  ): Promise<{
    readingTimePhysics: number;
    linear: Map<MotorData, Vector3>;
    rotation: Map<MotorData, Vector3>;
  }>;
}
