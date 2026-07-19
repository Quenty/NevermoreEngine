import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { Binder } from './Binder';

type ToBinderMap<T extends Record<string, unknown> | unknown> = {
  [K in keyof T]: Binder<T[K]>;
};

type BinderProvider<T extends Record<string, unknown> | unknown> =
  ToBinderMap<T> & {
    PromiseBinder(binderName: string): Promise<Binder<unknown>>;
    Init(serviceBag: ServiceBag): void;
    PromiseBindersAdded(): Promise;
    PromiseBindersStarted(): Promise;
    Start(): void;
    Get(tagName: string): Binder<unknown> | undefined;
    Add(binder: Binder<unknown>): void;
    Destroy(): void;
  };

interface BinderProviderConstructor {
  readonly ClassName: 'BinderProvider';
  readonly ServiceName: 'BinderProvider';
  new <T extends Record<string, unknown> | unknown>(
    serviceName: string,
    initMethod: (self: BinderProvider<T>, serviceBag: ServiceBag) => void
  ): BinderProvider<T>;

  isBinderProvider: (value: unknown) => value is BinderProvider<unknown>;
}

export const BinderProvider: BinderProviderConstructor;
