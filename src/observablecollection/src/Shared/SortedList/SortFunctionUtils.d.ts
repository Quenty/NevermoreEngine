type SortFunction<T> = (a: T, b: T) => number;

export namespace SortFunctionUtils {
  function reverse<T>(compare?: SortFunction<T>): SortFunction<T>;
  // cant use `default` as a function name because it is a reserved keyword
  // function default(a: any, b: any): number;
  function emptyIterator(): void;
}
