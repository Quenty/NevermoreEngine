type AccelTween = {
  p: number;
  v: number;
  a: number;
  t: number;
  rtime: number;
  pt: number;
};

interface AccelTweenConstructor {
  readonly ClassName: 'AccelTween';
  new (maxAcceleration?: number): AccelTween;
}

export const AccelTween: AccelTweenConstructor;
