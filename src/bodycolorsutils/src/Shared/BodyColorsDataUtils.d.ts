import {
  BodyColorsData,
  DataStoreSafeBodyColorsData,
} from './BodyColorsDataConstants';

export namespace BodyColorsDataUtils {
  function createBodyColorsData<T extends BodyColorsData>(bodyColorsData: T): T;
  function isBodyColorsData(value: unknown): value is BodyColorsData;
  function fromUniformColor(color: Color3): BodyColorsData;
  function fromBodyColors(bodyColors: BodyColors): BodyColorsData;
  function isDataStoreSafeBodyColorsData(
    value: unknown
  ): value is DataStoreSafeBodyColorsData;
  function toDataStoreSafeBodyColorsData(
    bodyColorsData: BodyColorsData
  ): DataStoreSafeBodyColorsData;
  function fromDataStoreSafeBodyColorsData(
    data: DataStoreSafeBodyColorsData
  ): BodyColorsData;
  function fromHumanoidDescription(
    humanoidDescription: HumanoidDescription
  ): BodyColorsData;
  function isUniformColor(bodyColorsData: BodyColorsData): boolean;
  function getUniformColor(bodyColorsData: BodyColorsData): Color3 | undefined;
  function toBodyColors(bodyColorsData: BodyColorsData): BodyColors;
  function applyToBodyColors(
    bodyColorsData: BodyColorsData,
    bodyColors: BodyColors
  ): void;
  function fromAttributes(instance: Instance): BodyColorsData;
  function setAttributes(
    instance: Instance,
    bodyColorsData: BodyColorsData
  ): void;
  function applyToHumanoidDescription(
    bodyColorsData: BodyColorsData,
    humanoidDescription: HumanoidDescription
  ): void;
}
