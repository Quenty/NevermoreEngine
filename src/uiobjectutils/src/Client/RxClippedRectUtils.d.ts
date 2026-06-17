import { Observable } from '@quenty/rx';

export namespace RxClippedRectUtils {
  function observeClippedRect(gui: GuiObject): Observable<Rect>;
  function observeClippedRectInScale(gui: GuiObject): Observable<Rect>;
}
