import { LinearValue } from './LinearValue';
import { Spring } from './Spring';

export namespace SpringUtils {
  function animating<T>(
    spring: Spring<T>,
    epsilon?: number
  ): LuaTuple<[boolean, T]>;
  function getVelocityAdjustment<T>(
    velocity: T,
    dampen: number,
    speed: number
  ): T;
  function toLinearIfNeeded<T>(value: T): LinearValue<T> | T;
  function fromLinearIfNeeded<T>(value: LinearValue<T> | T): T;
}
