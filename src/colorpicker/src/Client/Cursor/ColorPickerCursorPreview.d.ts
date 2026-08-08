import { BasicPane } from '@quenty/basicpane';
import { Signal } from '@quenty/signal';

interface ColorPickerCursorPreview extends BasicPane {
  PositionChanged: Signal<Vector2>;
  Gui: Frame;
  HintBackgroundColor(color: Color3): void;
  SetPosition(position: Vector2): void;
  GetPosition(): Vector2;
  SetColor(color: Color3): void;
  SetTransparency(transparency: number): void;
}

interface ColorPickerCursorPreviewConstructor {
  readonly ClassName: 'ColorPickerCursorPreview';
  new (): ColorPickerCursorPreview;
}

export const ColorPickerCursorPreview: ColorPickerCursorPreviewConstructor;
