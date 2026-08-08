import { InfluxDBPointSettings } from '../Config/InfluxDBPointSettings';

export interface InfluxDBPointTableData {
  measurementName?: string;
  timestamp?: DateTime | string | number;
  tags: Record<string, string>;
  fields: Record<string, string>;
}

interface InfluxDBPoint {
  SetMeasurementName(name: string | undefined): void;
  GetMeasurementName(): string | undefined;
  ToTableData(): InfluxDBPointTableData;
  SetTimestamp(timestamp: DateTime | undefined): void;
  AddTag(tagKey: string, tagValue: string): void;
  AddIntField(fieldName: string, value: number): void;
  AddUintField(fieldName: string, value: number): void;
  AddFloatField(fieldName: string, value: number): void;
  AddBooleanField(fieldName: string, value: boolean): void;
  AddStringField(fieldName: string, value: string): void;
  ToLineProtocol(pointSettings: InfluxDBPointSettings): string | undefined;
}

interface InfluxDBPointConstructor {
  readonly ClassName: 'InfluxDBPoint';
  new (measurementName?: string): InfluxDBPoint;

  fromTableData: (value: InfluxDBPointTableData) => InfluxDBPoint;
  isInfluxDBPoint: (value: unknown) => value is InfluxDBPoint;
}

export const InfluxDBPoint: InfluxDBPointConstructor;
