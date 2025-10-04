import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';
import { InfluxDBClientConfig } from '../Config/InfluxDBClientConfigUtils';
import {
  ConvertTime,
  InfluxDBTags,
} from '../../Shared/Config/InfluxDBPointSettings';
import { InfluxDBPoint } from '../../Shared/Write/InfluxDBPoint';
import { Promise } from '@quenty/promise';

interface InfluxDBWriteAPI extends BaseObject {
  RequestFinished: Signal;
  Destroying: Signal;
  SetPrintDebugWriteEnabled(printDebugEnabled: boolean): void;
  SetClientConfig(clientConfig: InfluxDBClientConfig): void;
  SetDefaultTags(tags: InfluxDBTags): void;
  SetConvertTime(convertTime: ConvertTime | undefined): void;
  QueuePoint(point: InfluxDBPoint): void;
  QueuePoints(points: InfluxDBPoint[]): void;
  PromiseFlush(): Promise;
}

interface InfluxDBWriteAPIConstructor {
  readonly ClassName: 'InfluxDBWriteAPI';
  new (org: string, bucket: string, precision?: string): InfluxDBWriteAPI;
}

export const InfluxDBWriteAPI: InfluxDBWriteAPIConstructor;
