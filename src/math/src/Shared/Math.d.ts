export namespace Math {
  function map(
    num: number,
    min0: number,
    max0: number,
    min1: number,
    max1: number
  ): number;
  function jitter(
    average: number,
    spread?: number | undefined,
    randomValue?: number | undefined
  ): number;
  function isNaN(value: number): boolean;
  function isFinite(num: number): boolean;
  function lerp(num0: number, num1: number, percent: number): number;
  function lawOfCosines(a: number, b: number, c: number): number | undefined;
  function round(number: number, precision?: number): number;
  function roundUp(number: number, precision: number): number;
  function roundDown(number: number, precision: number): number;
}
