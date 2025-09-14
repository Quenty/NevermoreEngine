import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

type AdorneeDataValue<T> = {
  Value: T;
  readonly Changed: Signal<Record<PropertyKey, unknown>>;
  Observe(): Observable<Record<PropertyKey, unknown>>;
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
