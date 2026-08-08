export interface InfluxDBWriteOptions {
  batchSize: number;
  maxBatchBytes: number;
  flushIntervalSeconds: number;
}

export namespace InfluxDBWriteOptionUtils {
  function getDefaultOptions(): InfluxDBWriteOptions;
  function createWriteOptions(
    options: InfluxDBWriteOptions
  ): Readonly<InfluxDBWriteOptions>;
  function isWriteOptions(value: unknown): value is InfluxDBWriteOptions;
}
