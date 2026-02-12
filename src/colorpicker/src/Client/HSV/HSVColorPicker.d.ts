import { BaseObject } from '@quenty/baseobject';
import { Maid } from '@quenty/maid';
import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';

interface HSVColorPicker extends BaseObject {
  Gui: Frame;
  ColorChanged: Signal<Vector3>;
  SetSize(height: number): void;
  SyncValue(color3Value: Color3Value): Maid;
  HintBackgroundColor(color: Color3): void;
  SetHSVColor(hsvColor: Vector3): void;
  GetHSVColor(): Vector3;
  SetColor(color: Color3): void;
  GetColor(): Color3;
  GetSizeValue(): ValueObject<Vector2>;
  GetMeasureValue(): ValueObject<Vector2>;
  SetTransparency(transparency: number): void;
}

interface HSVColorPickerConstructor {
  readonly ClassName: 'HSVColorPicker';
  new (): HSVColorPicker;
}

export const HSVColorPicker: HSVColorPickerConstructor;
