export interface InfluxDBClientConfig {
  url: string;
  token: string | Secret;
}

export namespace InfluxDBClientConfigUtils {
  function isClientConfig(value: unknown): value is InfluxDBClientConfig;
  function createClientConfig(
    config: InfluxDBClientConfig
  ): InfluxDBClientConfig;
}
