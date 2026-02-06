export namespace IKUtils {
  function getDampenedAngleClamp(
    maxAngle: number,
    dampenAreaAngle: number,
    dampenAreaFactor?: number
  ): (angle: number) => number;
}
