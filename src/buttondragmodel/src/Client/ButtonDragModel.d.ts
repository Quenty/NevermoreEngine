import { BaseObject } from '@quenty/baseobject';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface ButtonDragModel extends BaseObject {
  DragPositionChanged: Signal<Vector2>;
  IsDraggingChanged: Signal<boolean>;
  IsPressed(): boolean;
  ObserveIsPressed(): Observable<boolean>;
  ObserveIsPressedBrio(): Observable<Brio<true>>;
  ObserveDragDelta(): Observable<Vector2 | undefined>;
  GetDragDelta(): Vector2 | undefined;
  GetDragPosition(): Vector2 | undefined;
  ObserveDragPosition(): Observable<Vector2 | undefined>;
  SetClampWithinButton(clampWithinButton: boolean): void;
  SetButton(button: GuiButton): () => void;
}

interface ButtonDragModelConstructor {
  readonly ClassName: 'ButtonDragModel';
  new (initialButton?: GuiButton): ButtonDragModel;
}

export const ButtonDragModel: ButtonDragModelConstructor;
