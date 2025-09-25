import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';

interface AnimatedHighlightModel extends BaseObject {
  HighlightDepthMode: ValueObject<Enum.HighlightDepthMode | undefined>;
  FillColor: ValueObject<Color3 | undefined>;
  OutlineColor: ValueObject<Color3 | undefined>;
  FillTransparency: ValueObject<number>;
  OutlineTransparency: ValueObject<number>;
  Speed: ValueObject<number>;
  ColorSpeed: ValueObject<number>;
  TransparencySpeed: ValueObject<number>;
  FillSpeed: ValueObject<number>;
  Destroying: Signal;

  SetHighlightDepthMode(depthMode: Enum.HighlightDepthMode | undefined): void;
  SetTransparencySpeed(speed: number | undefined): void;
  SetColorSpeed(speed: number | undefined): void;
  SetSpeed(speed: number | undefined): void;
  SetFillColor(color: Color3 | undefined, doNotAnimate?: boolean): void;
  GetFillColor(): Color3 | undefined;
  SetOutlineColor(color: Color3 | undefined, doNotAnimate?: boolean): void;
  GetOutlineColor(): Color3 | undefined;
  SetOutlineTransparency(
    outlineTransparency: number | undefined,
    doNotAnimate?: boolean
  ): void;
  SetFillTransparency(
    fillTransparency: number | undefined,
    doNotAnimate?: boolean
  ): void;
}

interface AnimatedHighlightModelConstructor {
  readonly ClassName: 'AnimatedHighlightModel';
  new (): AnimatedHighlightModel;

  isAnimatedHighlightModel: (value: unknown) => value is AnimatedHighlightModel;
}

export const AnimatedHighlightModel: AnimatedHighlightModelConstructor;
