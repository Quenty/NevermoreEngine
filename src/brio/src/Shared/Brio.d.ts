import { Maid } from '../../../maid';
import { Signal } from '../../../signal/src/Shared/Signal';

type Brio<T extends unknown[] = unknown[]> = {
  Kill(): void;
  IsDead(): boolean;
  GetDiedSignal(): Signal;
  ErrorIfDead(): void;
  ToMaid(): Maid;
  ToMaidAndValue(): LuaTuple<[Maid, ...T]>;
  GetValue(): LuaTuple<[...T]>;
  GetPackedValues(): {
    n: number;
    [index: number]: T;
  };

  Destroy(): void;
};

interface BrioConstructor {
  readonly ClassName: 'Brio';
  new <T extends unknown[] = unknown[]>(...values: T): Brio<T>;

  DEAD: Brio;
}

export const Brio: BrioConstructor;
