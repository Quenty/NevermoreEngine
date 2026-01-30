import { ServiceBag } from '@quenty/servicebag';

interface MantleConfigProvider {
  Init(serviceBag: ServiceBag): void;
  Destroy(): void;
}

interface MantleConfigProviderConstructor {
  readonly ClassName: 'MantleConfigProvider';
  new (container: Instance): MantleConfigProvider;
}

export const MantleConfigProvider: MantleConfigProviderConstructor;
