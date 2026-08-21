export namespace Probability {
  function boxMuller(): number;
  function normal(mean: number, standardDeviation: number): number;
  function boundedNormal(
    mean: number,
    standardDeviation: number,
    hardMin: number,
    hardMax: number
  ): number;
  function erf(x: number): number;
  function cdf(zScore: number): number;
  function erfinv(x: number): number | undefined;
  function percentileToZScore(percentile: number): number | undefined;
}
