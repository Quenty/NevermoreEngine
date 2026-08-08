import { BaseObject } from '@quenty/baseobject';
import { ToPropertyObservableArgument } from '@quenty/blend';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';

interface ColorGradePalette extends BaseObject {
  SetDefaultSurfaceName(gradeName: string): void;
  HasGrade(gradeName: string): boolean;
  GetGrade(gradeName: string): LuaTuple<[grade: number, vividness: number]>;
  GetVividness(gradeName: string): number;
  Add(
    gradeName: string,
    colorGrade: number | ToPropertyObservableArgument<number>,
    vividness: ToPropertyObservableArgument<number>
  ): void;
  ObserveGrade(gradeName: string): Observable<number>;
  ObserveVividness(gradeName: string): Observable<number>;
  ObserveModified(
    gradeName: string,
    amount: number | Color3 | Observable<Color3 | number> | string,
    multiplier?: number | Observable<number>
  ): Observable<number>;
  ObserveOn(
    gradeName: string,
    newSurfaceName: number | Color3 | Observable<Color3 | number> | string,
    baseSurfaceName?: number | Color3 | Observable<Color3 | number> | string
  ): LuaTuple<[finalGrade: Observable<number>, vividness: Observable<number>]>;
  ObserveDefaultSurfaceGrade(): Observable<number>;
}

interface ColorGradePaletteConstructor {
  readonly ClassName: 'ColorGradePalette';
  new (): ColorGradePalette;
}

export const ColorGradePalette: ColorGradePaletteConstructor;
