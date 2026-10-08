import { ValueObjectLike } from '@quenty/valueobject';
import { Signal } from '@quenty/signal';

interface EncodedAttributeValue<T> extends ValueObjectLike<T> {
  Changed: Signal<T>;
  Destroy(): void;
}

interface EncodedAttributeValueConstructor {
  readonly ClassName: 'EncodedAttributeValue';
  new <T = never>(
    object: Instance,
    attributeName: string,
    encode: (value: T | undefined) => string | undefined,
    decode: (value: string) => T | undefined
  ): EncodedAttributeValue<T | undefined>;
  new <T>(
    object: Instance,
    attributeName: string,
    encode: (value: T) => string,
    decode: (value: string) => T,
    defaultValue: T
  ): EncodedAttributeValue<T>;
}

export const EncodedAttributeValue: EncodedAttributeValueConstructor;
