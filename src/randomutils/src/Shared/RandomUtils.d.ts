export namespace RandomUtils {
  function choice<T>(array: T[], random?: Random): T | undefined;
  function shuffledCopy<T>(array: T[], random?: Random): T[];
  function shuffle<T>(list: T[], random?: Random): void;
  function weightedChoice<T>(list: T[], random?: Random): T | undefined;
  function gaussianRandom(random?: Random): number;
  function randomUnitVector3(random?: Random): Vector3;
}
