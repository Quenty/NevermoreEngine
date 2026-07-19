import { BaseObject } from '@quenty/baseobject';
import { ToPropertyObservableArgument } from '@quenty/blend';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { Mountable, ValueObject } from '@quenty/valueobject';
import { ColorGradePalette } from './Grade/ColorGradePalette';
import { ColorSwatch } from './Swatch/ColorSwatch';

interface ColorPalette extends BaseObject {
  ColorSwatchAdded: Signal<string>;
  ColorGradeAdded: Signal<string>;
  GetSwatchNames(): string[];
  ObserveSwatchNames(): Observable<string[]>;
  ObserveSwatchNameList(): Observable<string[]>;
  ObserveSwatchNamesBrio(): Observable<Brio<string>>;
  GetGradeNames(): string[];
  ObserveGradeNameList(): Observable<string[]>;
  ObserveGradeNames(): Observable<string[]>;
  ObserveGradeNamesBrio(): Observable<Brio<string>>;
  GetColorValues(): Readonly<Record<string, ValueObject<Color3>>>;
  GetColor(
    color: string | Color3 | Color3Value,
    grade?: string | number,
    vividness?: string | number
  ): Color3;
  ObserveColor(
    color: string | Color3 | ToPropertyObservableArgument<Color3>,
    grade?: string | number | ToPropertyObservableArgument<number>,
    vividness?: string | number | ToPropertyObservableArgument<number>
  ): Observable<Color3>;
  SetDefaultSurfaceName(surfaceName: string): void;
  GetColorSwatch(colorName: string): string;
  ObserveOn: ColorGradePalette['ObserveOn'];
  GetColorValue(colorName: string): ValueObject<Color3>;
  GetGradeValue(): ValueObject<number>;
  GetVividnessValue(): ValueObject<number>;
  ObserveModifiedGrade: ColorGradePalette['ObserveModified'];
  ObserveGrade: ColorGradePalette['ObserveGrade'];
  ObserveVividness: ColorGradePalette['ObserveVividness'];
  GetSwatch(swatchName: string): ColorSwatch;
  SetColor(colorName: string, color: Mountable<Color3>): void;
  SetVividness(gradeName: string, vividness: Mountable<number>): void;
  SetColorGrade(gradeName: string, colorGrade: Mountable<number>): void;
  ObserveColorBaseGradeBetween(
    colorName: string,
    low: number,
    high: number
  ): Observable<number>;
  DefineColorGrade(
    gradeName: string,
    gradeValue?: Mountable<number>,
    vividness?: Mountable<number>
  ): ValueObject<number>;
  DefineColorSwatch(colorName: string, value?: Color3): ColorSwatch;
}

interface ColorPaletteConstructor {
  readonly ClassName: 'ColorPalette';
  new (): ColorPalette;
}

export const ColorPalette: ColorPaletteConstructor;
