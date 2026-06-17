interface ServiceBag {
  PrintInitialization(): void;
  GetService<T extends new (...args: unknown[]) => unknown>(
    service: T
  ): InstanceType<T>;
  GetService<T>(service: T): T;
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
