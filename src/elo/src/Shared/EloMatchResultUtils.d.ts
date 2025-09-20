import { EloMatchResult } from './EloMatchResult';

export namespace EloMatchResultUtils {
  function isEloMatchResult(value: unknown): value is EloMatchResult;
  function isEloMatchResultList(value: unknown): value is EloMatchResult[];
}
