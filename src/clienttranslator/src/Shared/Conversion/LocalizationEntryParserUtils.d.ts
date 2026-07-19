export type LocalizationDataTable = {
  [key: string | number]: string | LocalizationDataTable;
};

export type LocalizationDataTableResult = {
  [key: string | number]:
    | {
        Example: string;
        Key: string;
        Context: string;
        Source: string;
        Values: Record<string, string>;
      }
    | LocalizationDataTableResult;
};

export namespace LocalizationEntryParserUtils {
  function decodeFromInstance(
    tableName: string,
    sourceLocaleId: string,
    folder: Instance
  ): LocalizationDataTableResult;
  function decodeFromTable(
    tableName: string,
    localeId: string,
    dataTable: LocalizationDataTable
  ): LocalizationDataTableResult;
}
