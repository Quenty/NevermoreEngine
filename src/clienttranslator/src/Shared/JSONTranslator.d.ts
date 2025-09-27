import { ServiceBag } from '@quenty/servicebag';
import { LocalizationDataTable } from './Conversion/LocalizationEntryParserUtils';
import { Observable } from '@quenty/rx';
import { RoundingBehaviourType } from './Numbers/RoundingBehaviourTypes';
import { TranslationArgs } from '@quenty/localizedtextutils';
import { Promise } from '@quenty/promise';

interface JSONTranslator {
  readonly ServiceName: string;
  Init(serviceBag: ServiceBag): void;
  ObserveNumber(number: number | Observable<number>): Observable<string>;
  ObserveAbbreviatedNumber(
    number: number | Observable<number>,
    roundingBehaviourType?: RoundingBehaviourType,
    numSignificantDigits?: number
  ): Observable<string>;
  ObserveFormatByKey(
    translationKey: string,
    translationArgs?: TranslationArgs
  ): Observable<string>;
  PromiseFormatByKey(
    translationKey: string,
    translationArgs?: TranslationArgs
  ): Promise<string>;
  PromiseTranslator(): Promise<Translator>;
  ObserveTranslator(): Observable<Translator>;
  ObserveLocaleId(): Observable<string>;
  SetEntryValue(
    translationKey: string,
    source: string,
    context: string,
    localeId: string,
    text: string
  ): void;
  ObserveTranslation(
    prefix: string,
    text: string,
    translationArgs?: TranslationArgs
  ): Observable<string>;
  ToTranslationKey(prefix: string, text: string): string;
  GetLocaleId(): string;
  GetLocalizationTable(): LocalizationTable;
  PromiseLoaded(): Promise<Translator>;
  FormatByKey(
    translationKey: string,
    translationArgs?: TranslationArgs
  ): string;
  Destroy(): void;
}

interface JSONTranslatorConstructor {
  readonly ClassName: 'JSONTranslator';
  readonly ServiceName: 'JSONTranslator';
  new (
    translatorName: string,
    localeId: string,
    dataTable: LocalizationDataTable
  ): JSONTranslator;
}

export const JSONTranslator: JSONTranslatorConstructor;
