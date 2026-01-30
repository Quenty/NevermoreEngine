import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace GuiInteractionUtils {
  function observeInteractionEnabled(gui: GuiObject): Observable<boolean>;
  function observeInteractionEnabledBrio(
    gui: GuiObject
  ): Observable<Brio<true>>;
}
