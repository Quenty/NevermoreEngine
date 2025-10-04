import { Binder } from '@quenty/binder';

interface PlayerBinder<T> extends Binder<T> {}

interface PlayerBinderConstructor {
  readonly ClassName: 'PlayerBinder';
  new <T extends unknown[], R>(
    tag: string,
    boundClass: {
      new (...args: T): R;
    },
    ...args: T
  ): PlayerBinder<R>;
}

export const PlayerBinder: PlayerBinderConstructor;
