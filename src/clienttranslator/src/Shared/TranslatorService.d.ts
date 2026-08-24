import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface TranslatorService {
  readonly ServiceName: 'TranslatorService';
  Init(serviceBag: ServiceBag): void;
  GetLocalizationTable(): LocalizationTable;
  ObserveTranslator(): Observable<Translator>;
  PromiseTranslator(): Promise<Translator>;
  GetTranslator(): Translator | undefined;
  ObserveLocaleId(): Observable<string>;
  GetLocaleId(): string;
  Destroy(): void;
}
