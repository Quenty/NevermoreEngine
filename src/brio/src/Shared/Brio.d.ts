import { Maid } from '@quenty/maid';
import { Signal } from '@quenty/signal';

type ToTuple<T> = T extends [unknown, ...unknown] ? T : [T];

export type Brio<T = void> = {
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

  readonly DEAD: Brio;
  isBrio: (value: unknown) => value is Brio;
}

export const Brio: BrioConstructor;

export {};
