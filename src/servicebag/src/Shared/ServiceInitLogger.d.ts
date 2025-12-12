interface ServiceInitLogger {
  StartInitClock(serviceName: string): void;
  Print(): void;
}

interface ServiceInitLoggerConstructor {
  readonly ClassName: 'ServiceInitLogger';
  new (action: string): ServiceInitLogger;
}

export const ServiceInitLogger: ServiceInitLoggerConstructor;
