import { Brio } from '@quenty/brio';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export type TemplateDeclaration =
  | Instance
  | Observable<Brio<Instance>>
  | TemplateDeclaration[];

interface TemplateProvider {
  Init(serviceBag: ServiceBag): void;
  ObserveTemplate(templateName: string): Observable<Instance>;
  ObserveTemplateNamesBrio(): Observable<Brio<string>>;
  GetTemplate(templateName: string): Instance | undefined;
  PromiseCloneTemplate(templateName: string): Promise<Instance>;
  PromiseTemplate(templateName: string): Promise<Instance>;
  CloneTemplate(templateName: string): Instance | undefined;
  AddTemplates(container: TemplateDeclaration): () => void;
  IsTemplateAvailable(templateName: string): boolean;
  GetTemplateList(): Instance[];
  GetContainerList(): Instance[];
  Destroy(): void;
}

interface TemplateProviderConstructor {
  readonly ClassName: 'TemplateProvider';
  new (
    providerName: string,
    initialTemplate: TemplateDeclaration
  ): TemplateProvider;

  isTemplateProvider: (value: unknown) => value is TemplateProvider;
}

export const TemplateProvider: TemplateProviderConstructor;
