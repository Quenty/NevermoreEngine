type ToTuple<T> = T extends unknown[] ? T : [T];

type LinearValue<T = void> = {
  ToBaseValue(): T;
  GetMagnitude(): number;
  Magnitude: number;
  __add(other: LinearValue<T>): LinearValue<T>;
  __sub(other: LinearValue<T>): LinearValue<T>;
  __mul(scalar: number): LinearValue<T>;
  __div(scalar: number): LinearValue<T>;
  __eq(other: LinearValue<T>): boolean;
};

interface LinearValueConstructor {
  readonly ClassName: 'LinearValue';
  new <T>(
    constructor: (...values: number[]) => T,
    values: number[]
  ): LinearValue<T>;

  isLinear: (value: unknown) => value is LinearValue<unknown>;
  toLinearIfNeeded: <T>(value: T) => LinearValue<T> | T;
  fromLinearIfNeeded: <T>(value: LinearValue<T> | T) => T;
}

export const LinearValue: LinearValueConstructor;
