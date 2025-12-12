import { TemplateProvider } from './TemplateProvider';

interface TaggedTemplateProviderConstructor {
  readonly ClassName: 'TaggedTemplateProvider';
  new (providerName: string, tagName: string): TemplateProvider;
}

export const TaggedTemplateProvider: TaggedTemplateProviderConstructor;
