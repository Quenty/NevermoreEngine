import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { Binder } from './Binder';

interface BinderProvider {
  PromiseBinder(binderName: string): Promise<Binder<unknown>>;
  Init(serviceBag: ServiceBag): void;
  PromiseBindersAdded(): Promise;
  PromiseBindersStarted(): Promise;
  Start(): void;
  Get(tagName: string): Binder<unknown> | undefined;
  Add(binder: Binder<unknown>): void;
  Destroy(): void;
}

interface BinderProviderConstructor {
  readonly ClassName: 'BinderProvider';
  new (
    serviceName: string,
    initMethod: (self: BinderProvider, serviceBag: ServiceBag) => void
  ): BinderProvider;

  isBinderProvider: (value: unknown) => value is BinderProvider;
}

export const BinderProvider: BinderProviderConstructor;
