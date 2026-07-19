export namespace ScaleModelUtils {
  function scalePartSize(part: BasePart, scale: Vector3 | number): void;
  function scalePart(
    part: BasePart,
    scale: Vector3 | number,
    centroid: Vector3
  ): void;
  function scale(
    parts: BasePart[],
    scale: Vector3 | number,
    centroid: Vector3
  ): void;
  function createMeshFromPart(part: BasePart): FileMesh | undefined;
}
