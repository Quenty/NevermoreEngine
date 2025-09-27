import { Maid } from '@quenty/maid';
import { Signal } from '@quenty/signal';

type ToTuple<T> = T extends unknown[] ? T : [T];

type Brio<T = void> = {
  Kill(): void;
  IsDead(): boolean;
  GetDiedSignal(): Signal;
  ErrorIfDead(): void;
  ToMaid(): Maid;
  ToMaidAndValue(): LuaTuple<[Maid, ...ToTuple<T>]>;
  GetValue(): T extends [unknown, ...unknown[]] ? LuaTuple<T> : T;
  GetPackedValues(): {
    n: number;
    [index: number]: T;
  };

  Destroy(): void;
};

interface BrioConstructor {
  readonly ClassName: 'Brio';
  new <T>(value: T): Brio<T>;
  new <T>(...values: ToTuple<T>): Brio<T>;

  DEAD: Brio;
}

export const Brio: BrioConstructor;
