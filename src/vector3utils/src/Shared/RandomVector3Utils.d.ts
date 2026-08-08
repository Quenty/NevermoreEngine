export namespace RandomVector3Utils {
  function getRandomUnitVector(): Vector3;
  function gaussianRandom(mean: Vector3, spread: Vector3): Vector3;
  function getDirectedRandomUnitVector(
    direction: Vector3,
    angleRad: number
  ): Vector3;
}
