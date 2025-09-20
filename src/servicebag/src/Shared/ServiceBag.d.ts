interface ServiceBag {
  PrintInitialization(): void;
  GetService(service: any): unknown;
  GetService<T extends { new (): T }>(service: T): T;
  HasService(service: any): boolean;
  Init(): void;
  Start(): void;
  IsStarted(): boolean;
  Destroy(): void;
}

interface ServiceBagConstructor {
  readonly ClassName: 'ServiceBag';
  new (): ServiceBag;

  isServiceBag: (value: unknown) => value is ServiceBag;
}

export const ServiceBag: ServiceBagConstructor;
