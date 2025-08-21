import { Maid } from '../../../maid';
import { Signal } from '../../../signal/src/Shared/Signal';

type ToTuple<T> = T extends any[] ? T : [T];

type Brio<T = void> = {
  Kill(): void;
  IsDead(): boolean;
  GetDiedSignal(): Signal;
  ErrorIfDead(): void;
  ToMaid(): Maid;
  ToMaidAndValue(): LuaTuple<[Maid, ...ToTuple<T>]>;
  GetValue(): T;
  GetPackedValues(): {
    n: number;
    [index: number]: T;
  };

  Destroy(): void;
};

interface BrioConstructor {
  readonly ClassName: 'Brio';
  new <T>(...values: ToTuple<T>): Brio<T>;

  DEAD: Brio;
}

export const Brio: BrioConstructor;
