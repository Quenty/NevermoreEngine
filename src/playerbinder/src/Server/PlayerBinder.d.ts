import { Binder } from '@quenty/binder';

interface PlayerBinder extends Binder<unknown> {}

interface PlayerBinderConstructor {
  readonly ClassName: 'PlayerBinder';
  new <T extends unknown[]>(
    tag: string,
    boundClass: {
      new (...args: T): unknown;
    },
    ...args: T
  ): PlayerBinder;
}

export const PlayerBinder: PlayerBinderConstructor;
