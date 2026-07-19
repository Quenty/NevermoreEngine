export namespace EnumUtils {
  function encodeAsString(enumItem: EnumItem): string;
  function isOfType(
    expectedEnumType: Enum,
    enumItem: EnumItem
  ): LuaTuple<[success: boolean, err: string]>;
  function toEnum(
    enumType: Enum,
    value: EnumItem | number | string
  ): EnumItem | undefined;
  function isEncodedEnum(value: string): boolean;
  function decodeFromString(value: string): EnumItem | undefined;
}
