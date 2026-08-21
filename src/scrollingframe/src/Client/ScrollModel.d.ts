interface ScrollModel {
  TotalContentLength: number;
  ViewSize: number;
  Max: number;
  readonly ContentMax: number;
  Position: number;
  readonly BackBounceInputRange: number;
  readonly BackBounceRenderRange: number;
  readonly ContentScrollPercentSize: number;
  readonly RenderedContentScrollPercentSize: number;
  ContentScrollPercent: number;
  readonly RenderedContentScrollPercent: number;
  readonly BoundedRenderPosition: number;
  Velocity: number;
  Target: number;
  readonly AtRest: boolean;
  GetDisplacementPastBounds(): number;
  GetScale(timesOverBounds: number): number;
}

interface ScrollModelConstructor {
  readonly ClassName: 'ScrollModel';
  new (): ScrollModel;
}

export const ScrollModel: ScrollModelConstructor;
