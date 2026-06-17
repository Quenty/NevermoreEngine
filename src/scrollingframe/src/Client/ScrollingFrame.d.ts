import { ScrollType } from './SCROLL_TYPE';
import { Scrollbar } from './Scrollbar';
import { ScrollModel } from './ScrollModel';

export interface BindInputOptions {
  OnClick?: (inputBeganObject: InputObject) => void;
}

interface ScrollingFrame {
  SetScrollType(scrollType: ScrollType): void;
  AddScrollbar(scrollbar: Scrollbar): void;
  RemoveScrollbar(scrollbar: Scrollbar): void;
  ScrollTo(position: number): void;
  ScrollToTop(doNotAnimate?: boolean): void;
  ScrollToBottom(doNotAnimate?: boolean): void;
  GetModel(): ScrollModel;
  StopDrag(): void;
  BindInput(gui: GuiObject, options?: BindInputOptions): void;
  StartScrolling(
    inputBeganObject: InputObject,
    options?: BindInputOptions
  ): void;
  StartScrollbarScrolling(
    scrollbarContainer: GuiObject,
    inputBeganObject: InputObject
  ): void;
  Destroy(): void;
}

interface ScrollingFrameConstructor {
  readonly ClassName: 'ScrollingFrame';
  new (gui: GuiObject): ScrollingFrame;
}

export const ScrollingFrame: ScrollingFrameConstructor;
