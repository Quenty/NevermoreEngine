export interface FzyConfig {
  caseSensitive: boolean;
  gapLeadingScore: number;
  gapTrailingScore: number;
  gapInnerScore: number;
  consecutiveMatchScore: number;
  slashMatchScore: number;
  wordMatchScore: number;
  capitalMatchScore: number;
  dotMatchScore: number;
  maxMatchLength: number;
}

export namespace Fzy {
  function createConfig(config: Partial<FzyConfig>): FzyConfig;
  function isFzyConfig(value: unknown): value is FzyConfig;
  function hasMatch(
    config: FzyConfig,
    needle: string,
    haystack: string
  ): boolean;
  function isPerfectMatch(
    config: FzyConfig,
    needle: string,
    haystack: string
  ): boolean;
  function score(config: FzyConfig, needle: string, haystack: string): number;
  function positions(
    config: FzyConfig,
    needle: string,
    haystack: string
  ): LuaTuple<[indices: number[], score: number]>;
  function filter(
    config: FzyConfig,
    needle: string,
    haystacks: string[]
  ): [idx: number, positions: number[], score: number][];
  function getMinScore(): number;
  function getMaxScore(): number;
  function getMaxLength(config: FzyConfig): number;
  function getScoreFloor(config: FzyConfig): number;
  function getScoreCeiling(config: FzyConfig): number;
}
