type MathLike = number | Vector3 | Vector2;

type Quaternion = [w: number, x: number, y: number, z: number];

export namespace Quaternion {
  function BezierPosition<T extends MathLike>(
    x0: T,
    x1: T,
    v0: T,
    v1: T,
    t: number
  ): T;
  function BezierVelocity<T extends MathLike>(
    x0: T,
    x1: T,
    v0: T,
    v1: T,
    t: number
  ): T;
  function Qmul(q1: Quaternion, q2: Quaternion): Quaternion;
  function Qinv(q: Quaternion): Quaternion;
  function Qpow(q: Quaternion, exponent: number, choice?: number): Quaternion;
  function QuaternionFromCFrame(cf: CFrame): Quaternion;
  function SlerpQuaternions(
    q0: Quaternion,
    q1: Quaternion,
    t: number
  ): Quaternion;
  function QuaternionToCFrame(q: Quaternion): number[];
  function BezierRotation(
    q0: Quaternion,
    q1: Quaternion,
    w0: Quaternion,
    w1: Quaternion,
    t: number
  ): Quaternion;
  function BezierAngularV(
    q0: Quaternion,
    q1: Quaternion,
    w0: Quaternion,
    w1: Quaternion,
    t: number
  ): Quaternion;
  const Tweens: Record<PropertyKey, MathLike | undefined>;
  const QuaternionTweens: Record<PropertyKey, Quaternion | undefined>;
  const CFrameTweens: Record<PropertyKey, CFrame | undefined>;
  function updateTweens(timeNow: number): void;
  function updateQuaternionTweens(timeNow: number): void;
  function updateCFrameTweens(timeNow: number): void;
  function newTween<T extends MathLike>(
    name: unknown,
    value: T,
    updateFunction: (value: T) => void,
    time: number
  ): void;
  function newQuaternionTween(
    name: unknown,
    value: Quaternion,
    updateFunction: (value: Quaternion) => void,
    time: number,
    autoChoose?: boolean
  ): void;
  function newCFrameTween(
    name: unknown,
    value: CFrame,
    updateFunction: (value: CFrame) => void,
    time: number
  ): void;
}
