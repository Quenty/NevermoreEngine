export type InfluxDBTags = Record<string, string>;

export type ConvertTime = (time?: DateTime | number | string) => number;

interface InfluxDBPointSettings {
  SetDefaultTags(tags: InfluxDBTags): void;
  GetDefaultTags(): InfluxDBTags;
  SetConvertTime(convertTime: ConvertTime | undefined): void;
  GetConvertTime(): ConvertTime | undefined;
}

interface InfluxDBPointSettingsConstructor {
  readonly ClassName: 'InfluxDBPointSettings';
  new (): InfluxDBPointSettings;
}

export const InfluxDBPointSettings: InfluxDBPointSettingsConstructor;
