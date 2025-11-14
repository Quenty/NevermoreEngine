type Tuple<T> = {
  n: number;

  Unpack(): T extends [unknown, ...unknown[]] ? LuaTuple<T> : T;
  ToArray(): T extends [unknown, ...unknown[]] ? T : [T];
  __tostring(): string;
  __len(): number;
  __eq(other: Tuple<unknown>): boolean;
  _add(other: Tuple<unknown>): Tuple<unknown>;
  __call(): T extends [unknown, ...unknown[]] ? LuaTuple<T> : T;
};

interface TupleConstructor {
  readonly ClassName: 'Tuple';
  new <T>(value: T): Tuple<T>;
  new <T extends unknown[]>(...values: T): Tuple<T>;
  isTuple: (value: unknown) => value is Tuple<unknown>;
}

export const Tuple: TupleConstructor;
