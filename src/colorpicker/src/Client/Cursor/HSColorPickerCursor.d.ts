import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';

interface HSColorPickerCursor extends BaseObject {
  PositionChanged: Signal<Vector2>;
  Gui: Frame;
  HintBackgroundColor(color: Color3): void;
  SetVerticalHairVisible(visible: boolean): void;
  SetHorizontalHairVisible(visible: boolean): void;
  SetHeight(height: number): void;
  SetPosition(position: Vector2): void;
  GetPosition(): Vector2;
  SetTransparency(transparency: number): void;
}

interface HSColorPickerCursorConstructor {
  readonly ClassName: 'HSColorPickerCursor';
  new (): HSColorPickerCursor;
}

export const HSColorPickerCursor: HSColorPickerCursorConstructor;
