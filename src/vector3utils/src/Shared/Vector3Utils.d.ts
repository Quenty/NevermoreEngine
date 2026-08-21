export namespace Vector3Utils {
  function fromVector2XY(vector2: Vector2): Vector3;
  function fromVector2XZ(vector2: Vector2): Vector3;
  function getAngleRad(a: Vector3, b: Vector3): number | undefined;
  function reflect(vector: Vector3, unitNormal: Vector3): Vector3;
  function angleBetweenVectors(a: Vector3, b: Vector3): number;
  function slerp(start: Vector3, finish: Vector3, t: number): Vector3;
  function constrainToCone(
    direction: Vector3,
    coneDirection: Vector3,
    coneAngleRad: number
  ): Vector3;
  function round(vector3: Vector3, amount: number): Vector3;
  function areClose(a: Vector3, b: Vector3, epsilon: number): boolean;
}
