import { Signal } from '@quenty/signal';
import { Binder } from './Binder';

interface BinderGroup {
  BinderAdded: Signal<Binder<unknown>>;

  AddList<T extends unknown[]>(binders: { [K in keyof T]: Binder<T[K]> }): void;
  Add(binder: Binder<unknown>): void;
  GetBinders(): Binder<unknown>[];
}

interface BinderGroupConstructor {
  readonly ClassName: 'BinderGroup';
  new <T extends unknown[]>(
    binders: { [K in keyof T]: Binder<T[K]> },
    validateConstructor?: (constructor: unknown) => boolean
  ): BinderGroup;
}

export const BinderGroup: BinderGroupConstructor;
