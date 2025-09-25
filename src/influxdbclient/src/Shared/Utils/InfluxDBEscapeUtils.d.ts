export type EscapeTable = Record<string, string>;

export namespace InfluxDBEscapeUtils {
  function createEscaper(subTable: EscapeTable): (str: string) => string;
  function createQuotedEscaper(subTable: EscapeTable): (str: string) => string;
  const measurement: (str: string) => string;
  const quoted: (str: string) => string;
  const tag: (str: string) => string;
}
