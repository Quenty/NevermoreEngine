import { EloMatchResult } from './EloMatchResult';

export interface EloConfig {
  factor: number;
  kfactor: number | ((rating: number) => number);
  initial: number;
  ratingFloor: number;
  groupMultipleResultAsOne: boolean;
}

export namespace EloUtils {
  function createConfig(config?: Partial<EloConfig>): EloConfig;
  function isEloConfig(value: unknown): value is EloConfig;
  function getStandardDeviation(eloConfig: EloConfig): number;
  function getPercentile(eloConfig: EloConfig, elo: number): number;
  function percentileToElo(
    eloConfig: EloConfig,
    percentile: number
  ): number | undefined;
  function getNewElo(
    eloConfig: EloConfig,
    playerOneRating: number,
    playerTwoRating: number,
    eloMatchResultList: EloMatchResult[]
  ): LuaTuple<[newPlayerOneRating: number, newPlayerTwoRating: number]>;
  function getEloChange(
    eloConfig: EloConfig,
    playerOneRating: number,
    playerTwoRating: number,
    eloMatchResultList: EloMatchResult[]
  ): LuaTuple<[playerOneEloChange: number, playerTwoEloChange: number]>;
  function getNewPlayerOneScore(
    eloConfig: EloConfig,
    playerOneRating: number,
    playerTwoRating: number,
    eloMatchResultList: EloMatchResult[]
  ): number;
  function getPlayerOneExpected(
    eloConfig: EloConfig,
    playerOneRating: number,
    playerTwoRating: number
  ): number;
  function getPlayerOneScoreAdjustment(
    eloConfig: EloConfig,
    playerOneRating: number,
    playerTwoRating: number,
    eloMatchResultList: EloMatchResult[]
  ): number;
  function fromOpponentPerspective(
    eloMatchResultList: EloMatchResult[]
  ): EloMatchResult[];
  function countPlayerOneWins(eloMatchResultList: EloMatchResult[]): number;
  function countPlayerTwoWins(eloMatchResultList: EloMatchResult[]): number;
  function standardKFactorFormula(rating: number): number;
  function extractKFactor(eloConfig: EloConfig, rating: number): number;
}
