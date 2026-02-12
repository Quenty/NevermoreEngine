import { Maid } from '@quenty/maid';
import { Signal } from '@quenty/signal';

type CancelToken = {
  Cancelled: Signal;
  ErrorIfCancelled(): void;
  IsCancelled(): boolean;
};

interface CancelTokenConstructor {
  readonly ClassName: 'CancelToken';
  new (executor: (cancel: () => void, maid: Maid) => void): CancelToken;

  isCancelToken: (value: unknown) => value is CancelToken;
  fromMaid: (maid: Maid) => CancelToken;
  fromSeconds: (seconds: number) => CancelToken;
}

export const CancelToken: CancelTokenConstructor;
