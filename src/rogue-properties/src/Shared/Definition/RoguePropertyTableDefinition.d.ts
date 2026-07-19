import { ServiceBag } from '@quenty/servicebag';
import { RoguePropertyDefinition } from './RoguePropertyDefinition';
import { RoguePropertyDefinitionArrayHelper } from './RoguePropertyDefinitionArrayHelper';
import { RoguePropertyTable } from '../Implementation/RoguePropertyTable';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

export type ToDefinitionMap<T> = {
  [K in keyof T]: T[K] extends Record<PropertyKey, unknown>
    ? RoguePropertyTableDefinition<T[K]>
    : RoguePropertyDefinition<T[K]>;
};

type RoguePropertyTableDefinition<
  T extends Record<PropertyKey, T | unknown> | (T | unknown)[] | unknown
> = ToDefinitionMap<T> & {
  SetDefaultValue(value: T): void;
  CanAssign(
    mainValue: T
  ): LuaTuple<
    | [canAssign: true, errorMessage: undefined]
    | [canAssign: false, errorMessage: string]
  >;
  GetDefinitionArrayHelper(): RoguePropertyDefinitionArrayHelper;
  GetDefinitionMap(): T extends unknown[] ? {} : ToDefinitionMap<T>;
  GetDefinition<K extends keyof T>(
    propertyName: K
  ): RoguePropertyDefinition<T[K]>;
  Get(serviceBag: ServiceBag, adornee: Instance): RoguePropertyTable<T>;
  ObserveContainerBrio(
    adornee: Instance,
    canInitialize: boolean
  ): Observable<Brio<Folder>>;
  GetContainer(adornee: Instance, canInitialize: boolean): Folder | undefined;
  GetOrCreateInstance(parent: Instance): Folder;
};

interface RoguePropertyTableDefinitionConstructor {
  readonly ClassName: 'RoguePropertyTableDefinition';
  new <T = unknown>(
    tableName?: string,
    defaultValueTable?: T
  ): RoguePropertyTableDefinition<T>;

  isRoguePropertyTableDefinition: (
    value: unknown
  ) => value is RoguePropertyTableDefinition<unknown>;
}

export const RoguePropertyTableDefinition: RoguePropertyTableDefinitionConstructor;
