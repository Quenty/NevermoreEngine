export namespace R15Utils {
  function searchForRigAttachment(
    character: Model,
    partName: string,
    attachmentName: string
  ): Attachment | undefined;
  function getRigMotor(
    character: Model,
    partName: string,
    motorName: string
  ): Motor6D | undefined;
  function getUppertorso(character: Model): BasePart | undefined;
  function getLowerTorso(character: Model): BasePart | undefined;
  function getBodyPart(
    character: Model,
    partName: string
  ): BasePart | undefined;
  function getWaistJoint(character: Model): Motor6D | undefined;
  function getNeckJoint(character: Model): Motor6D | undefined;
  function getHand(
    character: Model,
    side: 'Left' | 'Right'
  ): BasePart | undefined;
  function getGripWeld(
    character: Model,
    side: 'Left' | 'Right'
  ): Motor6D | undefined;
  function getGripWeldName(side: 'Left' | 'Right'): 'LeftGrip' | 'RightGrip';
  function getHandName(side: 'Left' | 'Right'): 'LeftHand' | 'RightHand';
  function getGripAttachmentName(
    side: 'Left' | 'Right'
  ): 'LeftGripAttachment' | 'RightGripAttachment';
  function getShoulderRigAttachment(
    character: Model,
    side: 'Left' | 'Right'
  ): Attachment | undefined;
  function getGripAttachment(
    character: Model,
    side: 'Left' | 'Right'
  ): Attachment | undefined;
  function getExpectedRootPartYOffset(humanoid: Humanoid): number | undefined;
  function getRigLength(
    character: Model,
    partName: string,
    rigAttachment0: string,
    rigAttachment1: string
  ): number | undefined;
  function addLengthsOrNil(lengths: (number | undefined)[]): number | undefined;
  function getUpperArmRigLength(
    character: Model,
    side: 'Left' | 'Right'
  ): number | undefined;
  function getLowerArmRigLength(
    character: Model,
    side: 'Left' | 'Right'
  ): number | undefined;
  function getWristToGripLength(
    character: Model,
    side: 'Left' | 'Right'
  ): number | undefined;
  function getHumanoidScaleProperty(
    humanoid: Humanoid,
    scaleValueName: string
  ): number | undefined;
  function getArmRigToGripLength(
    character: Model,
    side: 'Left' | 'Right'
  ): number | undefined;
}
