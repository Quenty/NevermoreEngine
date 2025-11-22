import { ServiceBag } from '@quenty/servicebag';

interface Singleton {
  Init(serviceBag: ServiceBag): void;
}

interface SingletonConstructor {
  readonly ClassName: 'Singleton';
  new (
    serviceName: string,
    constructor: (...args: unknown[]) => unknown
  ): Singleton;
}

export const Singleton: SingletonConstructor;
