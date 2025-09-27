import { SerializedColor3 } from '@quenty/color3serializationutils';

export type BodyColorsData = {
  headColor: Color3 | undefined;
  leftArmColor: Color3 | undefined;
  leftLegColor: Color3 | undefined;
  rightArmColor: Color3 | undefined;
  rightLegColor: Color3 | undefined;
  torsoColor: Color3 | undefined;
};

export type DataStoreSafeBodyColorsData = {
  headColor: SerializedColor3 | undefined;
  leftArmColor: SerializedColor3 | undefined;
  leftLegColor: SerializedColor3 | undefined;
  rightArmColor: SerializedColor3 | undefined;
  rightLegColor: SerializedColor3 | undefined;
  torsoColor: SerializedColor3 | undefined;
};

export const BodyColorsDataConstants: Readonly<{
  ATTRIBUTE_MAPPING: {
    headColor: 'HeadColor';
    leftArmColor: 'LeftArmColor';
    leftLegColor: 'LeftLegColor';
    rightArmColor: 'RightArmColor';
    rightLegColor: 'RightLegColor';
    torsoColor: 'TorsoColor';
  };
}>;
