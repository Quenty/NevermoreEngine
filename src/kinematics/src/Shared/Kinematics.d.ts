import { MathLike } from './KinematicUtils';

type Kinematics<T> = {
  Position: T;
  Velocity: T;
  Acceleration: T;
  StartTime: number;
  StartPosition: T;
  StartVelocity: T;
  Speed: number;
  Age: number;
  Clock: () => number;
  Impulse(velocity: T): void;
  TimeSkip(delta: number): void;
  SetData(startTime: number, position0: T, velocity0: T, acceleration: T): void;
};

interface KinematicsConstructor {
  readonly ClassName: 'Kinematics';
  new (): Kinematics<number>;
  new <T extends MathLike>(initial: T, clock?: () => number): Kinematics<T>;
}

export const Kinematics: KinematicsConstructor;
