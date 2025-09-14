import { AttributeValue } from '@quenty/attributeutils';
import { Observable } from '@quenty/rx';
import { AdorneeDataValue } from './AdorneeDataValue';

export type ToAdorneeDictionary<
  T extends Record<PropertyKey, unknown> | unknown
> = T extends unknown
  ? {}
  : {
      [K in keyof T]: Readonly<
        T[K] extends Record<PropertyKey, unknown>
          ? ToAdorneeDictionary<T[K]>
          : AttributeValue<T[K]>
      >;
    };

type AdorneeData<T extends Record<PropertyKey, unknown>> =
  ToAdorneeDictionary<T> & {
    IsStrictData(
      data: unknown
    ): LuaTuple<[success: boolean, errorMessage: string]>;
    CreateStrictData<Y extends T>(data: Y): Readonly<Y>;
    CreateFullData(data: Partial<T>): Readonly<T>;
    CreateData<Y extends Partial<T>>(data: Y): Readonly<Y>;
    Observe(adornee: Instance): Observable<T>;
    Create(adornee: Instance): AdorneeDataValue<T>;
    Get(adornee: Instance): Readonly<T>;
    Set(adornee: Instance, data: Partial<T>): void;
    Unset(adornee: Instance): void;
    SetStrict(adornee: Instance, data: T): void;
    InitAttributes(adornee: Instance, data: Partial<T> | undefined): void;
    GetStrictTInterface(): (data: unknown) => data is T;
    GetTInterface(): (data: unknown) => data is Partial<T>;
    IsData(data: unknown): data is Partial<T>;
  };

interface AdorneeDataConstructor {
  readonly ClassName: 'AdorneeData';
  new <T extends Record<PropertyKey, unknown>>(prototype: T): AdorneeData<T>;
}

export const AdorneeData: AdorneeDataConstructor;
