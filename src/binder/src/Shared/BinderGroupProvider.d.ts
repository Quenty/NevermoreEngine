import { ServiceBag } from '@quenty/servicebag';
import { BinderGroup } from './BinderGroup';

interface BinderGroupProvider {
  Init(serviceBag: ServiceBag | undefined): void;
  Start(): void;
  Get(groupName: string): BinderGroup | undefined;
  Add(groupName: string, binderGroup: BinderGroup): void;
  Destroy(): void;
}

interface BinderGroupProviderConstructor {
  readonly ClassName: 'BinderGroupProvider';
  new (
    initMethod: (
      this: BinderGroupProvider,
      serviceBag: ServiceBag | undefined
    ) => void
  ): BinderGroupProvider;
}

export const BinderGroupProvider: BinderGroupProviderConstructor;
