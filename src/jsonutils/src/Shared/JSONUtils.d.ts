import { Promise } from '@quenty/promise';

export namespace JSONUtils {
  function jsonDecode(
    str: string
  ): LuaTuple<
    | [success: true, result: unknown, errorMessage: undefined]
    | [success: false, result: undefined, errorMessage: string]
  >;
  function jsonEncode(
    value: unknown
  ): LuaTuple<
    | [success: true, result: string, errorMessage: undefined]
    | [success: false, result: undefined, errorMessage: string]
  >;
  function promiseJSONDecode(str: string): Promise<unknown>;
}
