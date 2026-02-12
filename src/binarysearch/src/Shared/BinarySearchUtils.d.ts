export namespace BinarySearchUtils {
  function spanSearch(
    list: number[],
    t: number
  ): LuaTuple<[number | undefined, number | undefined]>;
  function spanSearchNodes<V>(
    list: V[],
    index: keyof V,
    t: number
  ): LuaTuple<[unknown | undefined, unknown | undefined]>;
  function spanSearchAnything(
    n: number,
    indexFunc: (index: number) => number,
    t: number
  ): LuaTuple<[number | undefined, number | undefined]>;
}
