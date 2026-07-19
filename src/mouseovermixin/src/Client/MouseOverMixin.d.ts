import { Maid } from '@quenty/maid';

export interface MouseOverMixin {
  GetMouseOverBoolValue(
    gui: GuiObject
  ): LuaTuple<[maid: Maid, mouseOver: BoolValue]>;
  AddMouseOverEffect<T extends GuiObject>(
    gui: T,
    tweenProperties?: Partial<WritableInstanceProperties<T>>
  ): BoolValue;
}

export const MouseOverMixin: {
  Add(classObj: { new (...args: unknown[]): unknown }): void;
};
