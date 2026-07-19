import { ServiceBag } from '@quenty/servicebag';
import { RoguePropertyTableDefinition } from './RoguePropertyTableDefinition';
import { EncodedRoguePropertyValue } from '../Implementation/RoguePropertyUtils';
import { RogueProperty } from '../Implementation/RogueProperty';

interface RoguePropertyDefinition<T> {
  SetDefaultValue(value: T): void;
  Get(serviceBag: ServiceBag, adornee: Instance): RogueProperty<T>;
  GetOrCreateInstance(parent: Instance): ValueBase;
  SetParentPropertyTableDefinition(
    parentPropertyTableDefinition: RoguePropertyTableDefinition<unknown>
  ): void;
  GetParentPropertyDefinition():
    | RoguePropertyTableDefinition<unknown>
    | undefined;
  CanAssign(
    value: unknown
  ): LuaTuple<
    | [canAssign: true, errorMessage: undefined]
    | [canAssign: false, errorMessage: string]
  >;
  SetName(name: string): void;
  GetName(): string;
  GetFullName(): string;
  GetDefaultValue(): T | undefined;
  GetValueType(): keyof CheckableTypes;
  GetStorageInstanceType(): string;
  GetEncodedDefaultValue(): EncodedRoguePropertyValue<T> | undefined;
}

interface RoguePropertyDefinitionConstructor {
  readonly ClassName: 'RoguePropertyDefinition';
  new (): RoguePropertyDefinition<unknown>;
  new <T>(): RoguePropertyDefinition<T>;

  isRoguePropertyDefinition(
    value: unknown
  ): value is RoguePropertyDefinition<unknown>;
}

export const RoguePropertyDefinition: RoguePropertyDefinitionConstructor;
