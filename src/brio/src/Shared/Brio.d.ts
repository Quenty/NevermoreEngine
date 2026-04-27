import { Maid } from '@quenty/maid';
import { Signal } from '@quenty/signal';

export type Brio<T = void> = {
  Kill(): void;
  IsDead(): boolean;
  GetDiedSignal(): Signal;
  ErrorIfDead(): void;
  ToMaid(): Maid;
  ToMaidAndValue(): LuaTuple<
    [Maid, ...(T extends LuaTuple<infer V> ? V : [T])]
  >;
  GetValue(): T extends LuaTuple<infer V> ? V : T;
  GetPackedValues(): {
    n: number;
    [index: number]: T;
  };

  Destroy(): void;
};

interface BrioConstructor {
  readonly ClassName: 'Brio';
  new (): Brio;
  new <T>(): Brio<T>;
  new <T>(value: T): Brio<T>;
  new <T extends unknown[]>(...values: T): Brio<LuaTuple<T>>;

  readonly DEAD: Brio;
  isBrio: (value: unknown) => value is Brio;
}

export const Brio: BrioConstructor;

export {};
