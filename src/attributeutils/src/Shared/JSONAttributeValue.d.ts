import { EncodedAttributeValue } from './EncodedAttributeValue';

interface JSONAttributeValue<T> extends EncodedAttributeValue<T> {}

interface JSONAttributeValueConstructor {
  readonly ClassName: 'JSONAttributeValue';
  new <T = never>(
    object: Instance,
    attributeName: string
  ): JSONAttributeValue<T | undefined>;
  new <T>(
    object: Instance,
    attributeName: string,
    defaultValue: T
  ): JSONAttributeValue<T>;
}

export const JSONAttributeValue: JSONAttributeValueConstructor;
