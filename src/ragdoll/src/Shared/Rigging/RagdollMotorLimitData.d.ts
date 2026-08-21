import { AdorneeData } from '@quenty/adorneedata';

export type MotorLimitData = {
  UpperAngle: number;
  TwistLowerAngle: number;
  TwistUpperAngle: number;
  FrictionTorque: number;
  ReferenceGravity: number;
  ReferenceMass: number;
};

export const RagdollMotorLimitData: Readonly<{
  NECK_LIMITS: AdorneeData<MotorLimitData>;
  WASIT_LIMITS: AdorneeData<MotorLimitData>;
  ANKLE_LIMITS: AdorneeData<MotorLimitData>;
  ELBOW_LIMITS: AdorneeData<MotorLimitData>;
  WRIST_LIMITS: AdorneeData<MotorLimitData>;
  KNEE_LIMITS: AdorneeData<MotorLimitData>;
  SHOULDER_LIMITS: AdorneeData<MotorLimitData>;
  HIP_LIMITS: AdorneeData<MotorLimitData>;

  R6_NECK_LIMITS: AdorneeData<MotorLimitData>;
  R6_SHOULDER_LIMITS: AdorneeData<MotorLimitData>;
  R6_HIP_LIMITS: AdorneeData<MotorLimitData>;
}>;
