import { EncodedAttributeValue } from './EncodedAttributeValue';

interface JSONAttributeValue<T> extends EncodedAttributeValue<T> {}

interface JSONAttributeValueConstructor {
  readonly ClassName: 'JSONAttributeValue';
  new <T = unknown>(
    object: Instance,
    attributeName: string,
    defaultValue?: T
  ): JSONAttributeValue<T>;
}

export const JSONAttributeValue: JSONAttributeValueConstructor;
