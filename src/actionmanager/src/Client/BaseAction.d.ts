import { EnabledMixin } from '@quenty/enabledmixin';
import { Maid } from '@quenty/maid';
import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';

export interface ActionData {
  Name: string;
  Shortcuts?: (Enum.KeyCode | Enum.UserInputType)[];
}

interface BaseAction<T = void> extends EnabledMixin {
  Activated: Signal<
    [
      actionMaid: Maid,
      ...activateData: T extends void ? [] : T extends unknown[] ? T : [T]
    ]
  >;
  Deactivated: Signal;
  IsActivatedValue: ValueObject<boolean>;
  GetName(): string;
  GetData(): ActionData;
  ToggleActivate(
    ...activateData: T extends void ? [] : T extends unknown[] ? T : [T]
  ): void;
  IsActive(): boolean;
  Deactivate(): void;
  Activate(
    ...activateData: T extends void ? [] : T extends unknown[] ? T : [T]
  ): void;
  Destroy(): void;
}

interface BaseActionConstructor {
  readonly ClassName: 'BaseAction';
  new <T extends unknown[] | void = void>(
    actionData: ActionData
  ): BaseAction<T>;
}

export const BaseAction: BaseActionConstructor;
