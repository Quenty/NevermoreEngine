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
  new <T extends keyof CheckableTypes | ValueInterface>(
    interface: T,
    createValueObject: (adornee: Instance) => ValueObjectLike<T extends (value: unknown) => value is infer V ? V : CheckableTypes[T]>,
    defaultValue?: T extends (value: unknown) => value is infer V ? NonNullable<V> : CheckableTypes[T]
  ): AdorneeDataEntry<T extends (value: unknown) => value is infer V ? V : CheckableTypes[T]>;

  isAdorneeDataEntry: (value: unknown) => value is AdorneeDataEntry<unknown>;
  optionalAttribute: (
    interface: string | ValueInterface,
    name: string
  ) => AdorneeDataEntry<unknown>;
}

export const AdorneeDataEntry: AdorneeDataEntryConstructor;
