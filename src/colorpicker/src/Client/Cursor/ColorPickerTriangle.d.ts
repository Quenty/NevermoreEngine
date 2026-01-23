import { BaseObject } from '@quenty/baseobject';
import { ValueObject } from '@quenty/valueobject';

interface ColorPickerTriangle extends BaseObject {
  Gui: Frame;
  HintBackgroundColor(color: Color3): void;
  GetSizeValue(): ValueObject<Vector2>;
  GetMeasureValue(): ValueObject<Vector2>;
  SetColor(color: Color3): void;
  SetTransparency(transparency: number): void;
}

interface ColorPickerTriangleConstructor {
  readonly ClassName: 'ColorPickerTriangle';
  new (): ColorPickerTriangle;
}

export const ColorPickerTriangle: ColorPickerTriangleConstructor;
