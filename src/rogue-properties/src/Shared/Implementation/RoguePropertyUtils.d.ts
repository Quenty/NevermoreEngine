import { RoguePropertyDefinition } from '../Definition/RoguePropertyDefinition';

export type EncodedRoguePropertyValue<T> = {
  readonly __brand: unique symbol;
  readonly __value: T;
};

export namespace RoguePropertyUtils {
  function encodeProperty<T>(
    definition: RoguePropertyDefinition<T>,
    value: T
  ): EncodedRoguePropertyValue<T>;
  function decodeProperty<T>(
    definition: RoguePropertyDefinition<T>,
    value: EncodedRoguePropertyValue<T>
  ): T;
}
