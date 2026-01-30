type QFrame = {
  toCFrame(): CFrame;
  toPosition(): Vector3;
};

interface QFrameConstructor {
  readonly ClassName: 'QFrame';
  new (
    x?: number,
    y?: number,
    z?: number,
    W?: number,
    X?: number,
    Y?: number,
    Z?: number
  ): QFrame;

  isQFrame: (value: unknown) => value is QFrame;
  fromCFrameClosestTo: (cframe: CFrame, closestTo: QFrame) => QFrame;
  fromVector3: (vector: Vector3, qframe: QFrame) => QFrame;
  isNAN: (qframe: QFrame) => boolean;
}

export const QFrame: QFrameConstructor;
