export namespace PseudoLocalize {
  function pseudoLocalize(line: string): string;
  function getDefaultPseudoLocaleId(): string;
  function addToLocalizationTable(
    localizationTable: LocalizationTable,
    preferredLocaleId?: string,
    preferredFromLocale?: string
  ): void;
  const PSEUDO_CHARACTER_MAP: Record<string, string>;
}
