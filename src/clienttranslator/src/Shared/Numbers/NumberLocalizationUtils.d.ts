import { RoundingBehaviourType } from './RoundingBehaviourTypes';

export namespace NumberLocalizationUtils {
  function localize(number: number, locale: string): string;
  function abbreviate(
    number: number,
    locale: string,
    roundingBehaviourType?: RoundingBehaviourType,
    numSignificantDigits?: number
  ): string;
}
