import { Signal } from '@quenty/signal';
import { ValueObjectLike } from '@quenty/valueobject';

interface AttributeValue<T> extends ValueObjectLike<T> {
  Changed: Signal;
  Destroy(): void;
}

interface AttributeValueConstructor {
  readonly ClassName: 'AttributeValue';
  new <T = unknown>(
    object: Instance,
    attributeName: string,
    defaultValue?: T
  ): AttributeValue<T>;
}

export const AttributeValue: AttributeValueConstructor;
