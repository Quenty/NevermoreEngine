import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';

interface HSColorPicker extends BaseObject {
  Gui: Frame;
  ColorChanged: Signal<Vector3>;
  ObserveIsPressed(): Observable<boolean>;
  SetHSVColor(hsvColor: Vector3): void;
  GetHSVColor(): Vector3;
  SetColor(color: Color3): void;
  GetColor(): Color3;
  GetSizeValue(): ValueObject<Vector2>;
  GetMeasureValue(): ValueObject<Vector2>;
  SetTransparency(transparency: number): void;
  SetSize(height: number): void;
}

interface HSColorPickerConstructor {
  readonly ClassName: 'HSColorPicker';
  new (): HSColorPicker;
}

export const HSColorPicker: HSColorPickerConstructor;
