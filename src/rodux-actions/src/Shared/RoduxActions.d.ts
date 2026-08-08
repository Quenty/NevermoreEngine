import { RoduxActionFactory } from './RoduxActionFactory';

interface RoduxActions {
  Init(): void;
  CreateReducer(
    initialState: unknown,
    handlers: Record<string, (state: unknown, action: unknown) => unknown>
  ): (
    state: unknown | undefined,
    action: { type: string; [key: string]: unknown }
  ) => unknown;
  Validate(action: Record<string, unknown>): boolean;
  Get(actionName: string): RoduxActionFactory | undefined;
  Add(
    actionName: string,
    typeTable: Record<string, (value: unknown) => boolean>
  ): RoduxActionFactory;
}

interface RoduxActionsConstructor {
  readonly ClassName: 'RoduxActions';
  readonly ServiceName: 'RoduxActions';
  new (initFunction: (this: RoduxActions) => void): RoduxActions;
}

export const RoduxActions: RoduxActionsConstructor;
