import { Maid } from '@quenty/maid';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

export namespace MultipleClickUtils {
  function observeDoubleClick(gui: GuiObject): Observable<InputObject>;
  function getDoubleClickSignal(
    maid: Maid,
    gui: GuiObject
  ): Signal<InputObject>;
  function observeMultipleClicks(
    gui: GuiObject,
    requiredCount: number
  ): Observable<InputObject>;
  function onMultipleClicks(
    requiredCount: number
  ): (gui: GuiObject) => Observable<InputObject>;
  function getMultipleClickSignal(
    maid: Maid,
    gui: GuiObject,
    requiredCount: number
  ): Signal<InputObject>;
}
