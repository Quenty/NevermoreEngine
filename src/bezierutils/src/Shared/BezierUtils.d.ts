export namespace BezierUtils {
  function createBezierFactory(
    p1x: number,
    p1y: number,
    p2x: number,
    p2y: number
  ): (aX: number) => number;
}
