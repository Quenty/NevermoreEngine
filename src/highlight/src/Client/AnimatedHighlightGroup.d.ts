import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { AnimatedHighlightModel } from './Stack/AnimatedHighlightModel';

interface AnimatedHighlightGroup extends BaseObject {
  SetDefaultHighlightDepthMode(depthMode: Enum.HighlightDepthMode): void;
  SetDefaultFillTransparency(transparency: number): void;
  SetDefaultOutlineTransparency(outlineTransparency: number): void;
  SetDefaultFillColor(color: Color3): void;
  GetDefaultFillColor(): Color3;
  SetDefaultOutlineColor(color: Color3): void;
  SetDefaultTransparencySpeed(speed: number): void;
  SetDefaultSpeed(speed: number): void;
  GetDefaultOutlineColor(): Color3;
  Highlight(
    adornee: Instance,
    observeScore?: number | Observable<number>
  ): AnimatedHighlightModel;
  HighlightWithTransferredProperties(
    fromAdornee: Instance,
    toAdornee: Instance,
    observeScore?: number | Observable<number>
  ): AnimatedHighlightModel;
}

interface AnimatedHighlightGroupConstructor {
  readonly ClassName: 'AnimatedHighlightGroup';
  new (): AnimatedHighlightGroup;
}

export const AnimatedHighlightGroup: AnimatedHighlightGroupConstructor;
