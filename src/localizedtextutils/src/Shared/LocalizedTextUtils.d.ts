import { JSONTranslator } from '@quenty/clienttranslator';
import { Observable } from '@quenty/rx';

export type TranslationArgs = Record<
  string,
  LocalizedTextData | number | string
>;

export interface LocalizedTextData {
  translationKey: string;
  translationArgs?: TranslationArgs;
}

export namespace LocalizedTextUtils {
  function create(
    translationKey: string,
    translationArgs?: TranslationArgs
  ): LocalizedTextData;
  function isLocalizedText(value: unknown): value is LocalizedTextData;
  function formatByKeyRecursive(
    translator: Translator | JSONTranslator,
    translationKey: string,
    translationArgs?: TranslationArgs,
    extraArgs?: unknown[] | Record<PropertyKey, unknown>
  ): string;
  function observeFormatByKeyRecursive(
    translator: JSONTranslator,
    translationKey: string,
    translationArgs?: TranslationArgs,
    extraArgs?: unknown[] | Record<PropertyKey, unknown>
  ): Observable<string>;
  function observeLocalizedTextToString(
    translator: JSONTranslator,
    localizedText: LocalizedTextData,
    extraArgs?: unknown[] | Record<PropertyKey, unknown>
  ): Observable<string>;
  function localizedTextToString(
    translator: Translator | JSONTranslator,
    localizedText: LocalizedTextData,
    extraArgs?: unknown[] | Record<PropertyKey, unknown>
  ): string;
  function fromJSON(text: string): LocalizedTextData | undefined;
  function toJSON(localizedText: LocalizedTextData): string;
  function setFromAttribute(
    obj: Instance,
    attributeName: string,
    translationKey: string,
    translationArgs: TranslationArgs
  ): void;
  function getFromAttribute(
    obj: Instance,
    attributeName: string
  ): LocalizedTextData | undefined;
  function getTranslationFromAttribute(
    translator: Translator | JSONTranslator,
    obj: Instance,
    attributeName: string,
    extraArgs?: unknown[] | Record<PropertyKey, unknown>
  ): string | undefined;
  function initializeAttribute(
    obj: Instance,
    attributeName: string,
    defaultTranslationKey: string,
    defaultTranslationArgs?: TranslationArgs
  ): void;
  function observeTranslation(
    translator: JSONTranslator,
    obj: Instance,
    attributeName: string,
    extraArgs?: unknown[] | Record<PropertyKey, unknown>
  ): Observable<string | undefined>;
}
