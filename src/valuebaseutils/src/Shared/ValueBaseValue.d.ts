import { ValueBaseType } from './ValueBaseUtils';
import { ValueObjectLike } from '@quenty/valueobject';

interface ValueBaseValue<T> extends ValueObjectLike<T> {}

interface ValueBaseValueConstructor {
  readonly ClassName: 'ValueBaseValue';
  new <T = unknown>(
    parent: Instance,
    className: ValueBaseType,
    name: string,
    defaultValue?: T
  ): ValueBaseValue<T>;
}

export const ValueBaseValue: ValueBaseValueConstructor;
