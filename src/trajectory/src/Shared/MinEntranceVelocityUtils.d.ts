export namespace MinEntranceVelocityUtils {
  function minimizeEntranceVelocity(
    origin: Vector3,
    target: Vector3,
    accel: Vector3
  ): Vector3;
  function computeEntranceVelocity(
    velocity: Vector3,
    origin: Vector3,
    target: Vector3,
    accel: Vector3
  ): Vector3;
  function computeEntranceTime(
    velocity: Vector3,
    origin: Vector3,
    target: Vector3,
    accel: Vector3
  ): Vector3;
}
