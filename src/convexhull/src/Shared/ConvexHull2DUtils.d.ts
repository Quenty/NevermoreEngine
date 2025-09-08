export namespace ConvexHull2DUtils {
  function convexHull(points: Vector2[]): Vector2[];
  function isClockWiseTurn(p1: Vector2, p2: Vector2, p3: Vector2): boolean;
  function lineIntersect(
    a: Vector2,
    b: Vector2,
    c: Vector2,
    d: Vector2
  ): Vector2 | undefined;
  function raycast(
    from: Vector2,
    to: Vector2,
    hull: Vector2[]
  ): LuaTuple<
    [point: Vector2 | undefined, startPoint: Vector2, finishPoint: Vector2]
  >;
}
