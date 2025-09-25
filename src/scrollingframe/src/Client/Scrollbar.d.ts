import { ScrollType } from './SCROLL_TYPE';

interface Scrollbar {
  SetScrollType(scrollType: ScrollType): void;
  SetScrollingFrame(scrollingFrame: ScrollingFrame): void;
  UpdateRender(): void;
  Destroy(): void;
}

interface ScrollbarConstructor {
  readonly ClassName: 'Scrollbar';
  new (gui: GuiObject, scrollType?: ScrollType): Scrollbar;

  fromContainer(container: GuiObject, scrollType?: ScrollType): Scrollbar;
}

export const Scrollbar: ScrollbarConstructor;
