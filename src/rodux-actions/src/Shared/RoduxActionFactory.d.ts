interface RoduxActionFactory {
  GetType(): string;
  __call(...args: unknown[]): unknown;
  CreateDispatcher(dispatch: () => void): (...args: unknown[]) => unknown;
  Create(action: Record<string, unknown>): unknown;
  Validate(action: Record<string, unknown>): boolean;
  Is(action: Record<string, unknown>): boolean;
  IsApplicable(action: Record<string, unknown>): boolean;
}

interface RoduxActionFactoryConstructor {
  readonly ClassName: 'RoduxActionFactory';
  new (
    actionName: string,
    typeTable: Record<string, (value: unknown) => boolean>
  ): RoduxActionFactory;
}

export const RoduxActionFactory: RoduxActionFactoryConstructor;
