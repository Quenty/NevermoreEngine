import { ValueTypeToDefaultValueType } from '@quenty/defaultvalueutils';
import { RoguePropertyDefinition } from '../Definition/RoguePropertyDefinition';
import {
  RoguePropertyTableDefinition,
  ToDefinitionMap,
} from '../Definition/RoguePropertyTableDefinition';

type prop<T> = {
  value: T;
};

type recurse<T> = {
  [K in keyof T]: T[K] extends Record<PropertyKey, unknown>
    ? recurse<T[K]>
    : prop<T[K]>;
};

type x = recurse<{ a: { b: { c: number } } }>;
type y = recurse<[number, string, number]>;

export namespace RoguePropertyArrayUtils {
  function getNameFromIndex(index: number): string;
  function getIndexFromName(name: string): number | undefined;
  function createRequiredPropertyDefinitionFromArray<T>(
    arrayData: T[],
    parentPropertyTableDefinition: RoguePropertyTableDefinition<unknown>
  ): LuaTuple<
    | [roguePropertyDefinition: undefined, errorMessage: string]
    | [
        roguePropertyDefinition: T extends (infer U)[]
          ? RoguePropertyTableDefinition<U>
          : RoguePropertyDefinition<T>,
        errorMessage: undefined
      ]
  >;
  function createRequiredTableDefinition<T>(
    arrayData: T[]
  ):
    | [
        roguePropertyTableDefinition: RoguePropertyTableDefinition<
          T extends (infer V)[] ? V : never
        >,
        errorMessage: undefined
      ]
    | [roguePropertyTableDefinition: undefined, errorMessage: string];
  function createRequiredPropertyDefinitionFromType<
    T extends string | keyof ValueTypeToDefaultValueType
  >(
    expectedType: T,
    parentPropertyTableDefinition: RoguePropertyTableDefinition<unknown>
  ): LuaTuple<
    | [roguePropertyDefinition: undefined, errorMessage: string]
    | [
        roguePropertyDefinition: RoguePropertyDefinition<
          T extends keyof ValueTypeToDefaultValueType
            ? ValueTypeToDefaultValueType[T]
            : unknown
        >,
        errorMessage: undefined
      ]
  >;
  function createDefinitionsFromContainer<T>(
    container: Instance,
    parentPropertyTableDefinition: RoguePropertyTableDefinition<T>
  ): ToDefinitionMap<T>;
  function getDefaultValueMapFromContainer(container: Instance): unknown;
  function createDefinitionsFromArrayData<T extends unknown[]>(
    arrayData: T,
    propertyTableDefinition: RoguePropertyTableDefinition<unknown>
  ): ToDefinitionMap<T>;
}
