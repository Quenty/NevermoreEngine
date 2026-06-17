export namespace UIRotationUtils {
  function toUnitCircle(rotationDegrees: number): number;
  function toUnitCircleDirection(rotationDegrees: number): Vector2;
  function toGuiDirection(unitCircleDirection: Vector2): Vector2;
}
