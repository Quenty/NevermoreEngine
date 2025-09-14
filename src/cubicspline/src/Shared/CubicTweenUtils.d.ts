type MathLike = number | Vector3 | Vector2;

export namespace CubicTweenUtils {
  function getConstants(
    l: number,
    t: number
  ): LuaTuple<[a0: number, a1: number, a2: number, a3: number]>;
  function getDerivativeConstants(
    l: number,
    t: number
  ): LuaTuple<[b0: number, b1: number, b2: number, b3: number]>;
  function applyConstants<T extends MathLike>(
    c0: number,
    c1: number,
    c2: number,
    c3: number,
    a: T,
    u: T,
    b: T,
    v: T
  ): MathLike;
  function tween<T extends MathLike>(
    a: T,
    u: T,
    b: T,
    v: T,
    l: number,
    t: number
  ): T;
  function getAcceleration<T extends MathLike>(
    a: T,
    u: T,
    b: T,
    v: T,
    l: number
  ): T;
}
