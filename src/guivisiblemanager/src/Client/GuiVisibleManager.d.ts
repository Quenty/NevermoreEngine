import { BaseObject } from '@quenty/baseobject';
import { BasicPane } from '@quenty/basicpane';
import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';
import { Signal } from '@quenty/signal';

interface GuiVisibleManager extends BaseObject {
  PaneVisibleChanged: Signal<boolean>;
  IsVisible(): boolean;
  BindToBoolValue(boolValue: BoolValue): void;
  CreateShowHandle(doNotAnimate?: boolean): { Destroy(): void };
}

interface GuiVisibleManagerConstructor {
  readonly ClassName: 'GuiVisibleManager';
  new (
    promiseNewPane: (maid: Maid) => Promise<BasicPane>,
    maxHideTime?: number
  ): GuiVisibleManager;
}

export const GuiVisibleManager: GuiVisibleManagerConstructor;
