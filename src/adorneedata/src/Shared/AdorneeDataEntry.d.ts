import { AttributeValue } from '@quenty/attributeutils';
import { Observable } from '@quenty/rx';
import { ValueObjectLike } from '@quenty/valueobject';

type ValueInterface = (
  value: unknown
) =>
  | boolean
  | (
      | LuaTuple<[success: true, errorMessage: undefined]>
      | LuaTuple<[success: false, errorMessage: string]>
    );

type AdorneeDataEntry<T> = {
  Create(adornee: Instance): AttributeValue<T>;
  Observe(adornee: Instance): Observable<T>;
  Get(adornee: Instance): T;
  Set(adornee: Instance, value: T): void;
  GetDefaultValue(): T | undefined;
  GetStrictInterface(): ValueInterface;
  IsValid(value: unknown): value is T;
};

interface AdorneeDataEntryConstructor {
  readonly ClassName: 'AdorneeDataEntry';
  new <T>(
    interface: string | ValueInterface,
    createValueObject: (adornee: Instance) => ValueObjectLike<unknown>,
    defaultValue?: T
  ): AdorneeDataEntry<T>;

  isAdorneeDataEntry: (value: unknown) => value is AdorneeDataEntry<unknown>;
  optionalAttribute: (
    interface: string | ValueInterface,
    name: string
  ) => AdorneeDataEntry<unknown>;
}

export const AdorneeDataEntry: AdorneeDataEntryConstructor;
