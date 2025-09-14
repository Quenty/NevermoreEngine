import { Observable } from '@quenty/rx';
import { ValueObject } from '@quenty/valueobject';

type ValueInterface = (
  value: unknown
) => LuaTuple<[success: boolean, errorMessage?: string]>;

type AdorneeDataEntry<T> = {
  optionalAttribute(
    interface: string | ValueInterface,
    name: string
  ): AdorneeDataEntry<Partial<T>>;
  Create(adornee: Instance): ValueObject<T>;
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
    createValueObject: (adornee: Instance) => ValueObject<unknown>,
    defaultValue?: T
  ): AdorneeDataEntry<T>;

  isAdorneeDataEntry: (value: unknown) => value is AdorneeDataEntry<unknown>;
}

export const AdorneeDataEntry: AdorneeDataEntryConstructor;
