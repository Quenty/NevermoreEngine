type MathLike = number | Vector3 | Vector2;

export namespace KinematicUtils {
  function positionVelocity<T extends MathLike>(
    now: number,
    t0: number,
    p0: T,
    v0: T,
    a0: T
  ): T;
}
