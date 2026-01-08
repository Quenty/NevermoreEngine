import { AccelTween } from '@quenty/acceltween';
import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface ButtonHighlightModel extends BaseObject {
  InteractionEnabledChanged: Signal<boolean>;
  IsSelectedChanged: Signal<boolean>;
  IsMouseOrTouchOverChanged: Signal<boolean>;
  IsHighlightedChanged: Signal<boolean>;
  IsPressedChanged: Signal<boolean>;
  SetButton(button: GuiObject | undefined): void;
  IsPressed(): boolean;
  ObserveIsPressed(): Observable<boolean>;
  ObservePercentPressed(acceleration?: number): Observable<number>;
  ObservePercentPressedTarget(): Observable<number>;
  IsHighlighted(): boolean;
  ObserveIsHighlighted(): Observable<boolean>;
  ObservePercentHighlightedTarget(): Observable<number>;
  ObservePercentHighlighted(acceleration?: number): Observable<number>;
  IsSelected(): boolean;
  ObserveIsSelected(): Observable<boolean>;
  IsMouseOrTouchOver(): boolean;
  ObserveIsMouseOrTouchOver(): Observable<boolean>;
  SetIsChoosen(isChoosen: boolean, doNotAnimate?: boolean): void;
  IsChoosen(): boolean;
  ObserveIsChoosen(): Observable<boolean>;
  ObservePercentChoosenTarget(): Observable<number>;
  ObservePercentChoosen(acceleration?: number): Observable<number>;
  SetInteractionEnabled(interactionEnabled: boolean): void;
  IsInteractionEnabled(): boolean;
  ObserveIsInteractionEnabled(): Observable<boolean>;
  SetKeyDown(isKeyDown: boolean, doNotAnimate?: boolean): void;
}

interface ButtonHighlightModelConstructor {
  readonly ClassName: 'ButtonHighlightModel';
  new (
    button?: GuiObject,
    onUpdate?: (
      percentHighlighted: AccelTween,
      percentChoosen: AccelTween,
      percentPressed: AccelTween
    ) => boolean
  ): ButtonHighlightModel;
}

export const ButtonHighlightModel: ButtonHighlightModelConstructor;
