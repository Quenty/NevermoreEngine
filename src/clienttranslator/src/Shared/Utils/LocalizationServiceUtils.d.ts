import { Promise } from '@quenty/promise';

export namespace LocalizationServiceUtils {
  function promiseTranslatorForLocale(localeId: string): Promise<Translator>;
  function promisePlayerTranslator(player: Player): Promise<Translator>;
}
