import { BaseObject } from '@quenty/baseobject';
import { InfluxDBClientConfig } from './Config/InfluxDBClientConfigUtils';
import { InfluxDBWriteAPI } from './Write/InfluxDBWriteAPI';
import { Promise } from '@quenty/promise';

interface InfluxDBClient extends BaseObject {
  SetClientConfig(clientConfig: InfluxDBClientConfig): void;
  GetWriteAPI(
    org: string,
    bucket: string,
    precision?: string
  ): InfluxDBWriteAPI;
  PromiseFlushAll(): Promise;
}

interface InfluxDBClientConstructor {
  readonly ClassName: 'InfluxDBClient';
  new (clientConfig?: InfluxDBClientConfig): InfluxDBClient;
}

export const InfluxDBClient: InfluxDBClientConstructor;
