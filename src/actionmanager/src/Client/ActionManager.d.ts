import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';
import { BaseAction } from './BaseAction';

interface ActionManager {
  ActiveAction: ValueObject<BaseAction | undefined>;
  ActionAdded: Signal<BaseAction>;
  StopCurrentAction(): void;
  ActivateAction<T extends BaseAction>(action: T, ...args: unknown[]): void;
  GetAction(name: string): BaseAction | undefined;
  GetActions(): BaseAction[];
  AddAction(action: BaseAction): void;
  Destroy(): void;
}

interface ActionManagerConstructor {
  readonly ClassName: 'ActionManager';
  new (parent?: Instance): ActionManager;

  ExtraPixels: 2;
}

export const ActionManager: ActionManagerConstructor;
