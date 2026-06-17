import { AdorneeData, AdorneeDataEntry } from '@quenty/adorneedata';
import { AttributeValue } from '@quenty/attributeutils';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { ValueObjectLike } from '@quenty/valueobject';

type MapToValues<T extends Record<PropertyKey, unknown> | unknown> =
  T extends Record<PropertyKey, unknown>
    ? Readonly<{
        [K in keyof T]: T[K] extends AdorneeDataEntry<infer V>
          ? ValueObjectLike<V>
          : AttributeValue<T[K]>;
      }>
    : {};

export type FromAdorneeData<T extends AdorneeData<unknown>> =
      T extends AdorneeData<infer U> ? AdorneeDataValue<U> : never;

type AdorneeDataValue<T> = MapToValues<T> & {
  Value: T;
  readonly Changed: Signal<T>;
  Observe(): Observable<T>;
};

interface AdorneeDataValueConstructor {
  readonly ClassName: 'AdorneeDataValue';
  new <T>(
    adornee: Instance,
    prototype: Record<PropertyKey, unknown>
  ): AdorneeDataValue<T>;

  isAdorneeDataValue: (value: unknown) => value is AdorneeDataValue<unknown>;
}

export const AdorneeDataValue: AdorneeDataValueConstructor;
