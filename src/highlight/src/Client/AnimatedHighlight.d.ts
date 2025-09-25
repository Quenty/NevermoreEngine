import { BasicPane } from '@quenty/basicpane';
import { Signal } from '@quenty/signal';

interface AnimatedHighlight extends BasicPane {
  Destroying: Signal;
  SetHighlightDepthMode(depthMode: Enum.HighlightDepthMode): void;
  SetPropertiesFrom(sourceHighlight: AnimatedHighlight): void;
  SetTransparencySpeed(speed: number): void;
  SetColorSpeed(speed: number): void;
  SetSpeed(speed: number): void;
  Finish(doNotAnimate: boolean, callback: () => void): void;
  SetFillColor(color: Color3, doNotAnimate?: boolean): void;
  SetOutlineColor(color: Color3, doNotAnimate?: boolean): void;
  SetAdornee(adornee: Instance | undefined): void;
  GetAdornee(): Instance | undefined;
  SetOutlineTransparency(
    outlineTransparency: number,
    doNotAnimate?: boolean
  ): void;
  SetFillTransparency(fillTransparency: number, doNotAnimate?: boolean): void;
}

interface AnimatedHighlightConstructor {
  readonly ClassName: 'AnimatedHighlight';
  new (): AnimatedHighlight;

  isAnimatedHighlight: (value: unknown) => value is AnimatedHighlight;
}

export const AnimatedHighlight: AnimatedHighlightConstructor;
