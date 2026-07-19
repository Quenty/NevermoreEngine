import { ServiceBag } from '@quenty/servicebag';
import { RoguePropertyTableDefinition } from '../Definition/RoguePropertyTableDefinition';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { RogueProperty } from './RogueProperty';
import { Signal } from '@quenty/signal';

export type ToRogueProperties<T> = {
  readonly [K in keyof T]: T[K] extends Record<PropertyKey, unknown>
    ? RoguePropertyTable<T[K]>
    : RogueProperty<T[K]>;
};

type RoguePropertyTable<T> = Omit<
  Omit<RogueProperty<T>, 'Changed'>,
  'Observe'
> &
  ToRogueProperties<T> & {
    Value: T;
    readonly Changed: Signal<ToRogueProperties<T>>;

    SetCanInitialize(canInitialize: boolean): void;
    ObserveContainerBrio(): Observable<Brio<Folder>>;
    GetContainer(): Folder | undefined;
    SetBaseValues(newBaseValue: T): void;
    SetValue(newValue: T): void;
    GetRogueProperties(): ToRogueProperties<T>;
    GetValue(): T;
    GetBaseValue(): T;
    Observe(): Observable<ToRogueProperties<T>>;
    GetRogueProperty<K extends keyof T>(name: K): RogueProperty<T[K]>;
  };

interface RoguePropertyTableConstructor {
  readonly ClassName: 'RoguePropertyTable';
  new <T>(
    adornee: Instance,
    serviceBag: ServiceBag,
    roguePropertyTableDefinition: RoguePropertyTableDefinition<T>
  ): RoguePropertyTable<T>;
}

export const RoguePropertyTable: RoguePropertyTableConstructor;
