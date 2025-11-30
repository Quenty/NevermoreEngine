export namespace PolynomialUtils {
  function solveOrderedRealLinear(a: number, b: number): number | undefined;
  function solveOrderedRealQuadratic(
    a: number,
    b: number,
    c: number
  ): LuaTuple<[number | undefined, number | undefined]>;
}
