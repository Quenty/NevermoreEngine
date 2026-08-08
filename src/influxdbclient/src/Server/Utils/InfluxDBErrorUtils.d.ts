export interface InfluxDBError {
  code: string;
  message: string;
}

export namespace InfluxDBErrorUtils {
  function tryParseErrorBody(body: string): InfluxDBError | undefined;
  function isInfluxDBError(value: unknown): value is InfluxDBError;
}
