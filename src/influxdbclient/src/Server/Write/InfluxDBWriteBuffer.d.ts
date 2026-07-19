import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { InfluxDBWriteOptions } from '../Config/InfluxDBWriteOptionUtils';

interface InfluxDBWriteBuffer extends BaseObject {
  Add(entry: string): void;
  PromiseFlush(): Promise;
}

interface InfluxDBWriteBufferConstructor {
  readonly ClassName: 'InfluxDBWriteBuffer';
  new (
    writeOptions: InfluxDBWriteOptions,
    promiseHandleFlush: (entries: string[]) => Promise
  ): InfluxDBWriteBuffer;
}

export const InfluxDBWriteBuffer: InfluxDBWriteBufferConstructor;
