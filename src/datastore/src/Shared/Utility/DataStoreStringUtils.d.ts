export namespace DataStoreStringUtils {
  function isValidUTF8(
    str: string
  ): LuaTuple<
    | [success: true, errorMessage: undefined]
    | [success: false, errorMessage: string]
  >;
}
