type Spring<T> = {
  Value: T;
  Velocity: T;
  Target: T;
  Damper: number;
  Speed: number;
  Clock: () => number;
  Impulse(velocity: T): void;
  TimeSkip(delta: number): void;
  SetTarget(value: T, doNotAnimate?: boolean): void;
};

interface SpringConstructor {
  readonly ClassName: 'Spring';
  new (): Spring<number>;
  new <T>(value: T, springClock?: () => number): Spring<T>;
}

export const Spring: SpringConstructor;
