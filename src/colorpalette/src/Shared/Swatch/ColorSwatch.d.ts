import { BaseObject } from '@quenty/baseobject';
import { ToPropertyObservableArgument } from '@quenty/blend';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { Mountable } from '@quenty/valueobject';

interface ColorSwatch extends BaseObject {
  Changed: Signal<Color3>;
  GetGraded(colorGrade: number): Color3;
  ObserveGraded(
    colorGrade: number | Observable<number>,
    vividness?: number | ToPropertyObservableArgument<number>
  ): Observable<Color3>;
  ObserveBaseColor(): Observable<Color3>;
  ObserveVividness(): Observable<number>;
  GetBaseColor(): Color3;
  GetBaseGrade(): number;
  ObserveBaseGrade(): Observable<number>;
  ObserveBaseGradeBetween(low: number, high: number): Observable<number>;
  GetVividness(): number;
  SetVividness(
    vividness: number | ToPropertyObservableArgument<number> | undefined
  ): void;
  SetBaseColor(color: Mountable<Color3>): void;
}

interface ColorSwatchConstructor {
  readonly ClassName: 'ColorSwatch';
  new (color: Mountable<Color3>, vividness?: number): ColorSwatch;
}

export const ColorSwatch: ColorSwatchConstructor;
