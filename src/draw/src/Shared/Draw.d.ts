export namespace Draw {
  type Vector3Like =
    | Vector3
    | CFrame
    | Attachment
    | BasePart
    | Model
    | RaycastResult
    | PathWaypoint;
  type Color3Like = Color3 | BrickColor | BasePart;
  type CFrameLike =
    | CFrame
    | Vector3
    | Attachment
    | BasePart
    | Model
    | RaycastResult
    | PathWaypoint;

  function setColor(color: Color3): void;
  function resetColor(): void;
  function setRandomColor(): void;
  function line(
    start: Vector3,
    finish: Vector3,
    color?: Color3Like,
    parent?: Instance,
    diameter?: number
  ): BasePart;
  function direction(
    origin: Vector3,
    direction: Vector3,
    color?: Color3,
    parent?: Instance,
    diameter?: number
  ): BasePart;
  function spherecast(
    origin: Vector3Like,
    radius: number,
    direction: Vector3Like,
    color?: Color3Like,
    parent?: Instance
  ): Folder;
  function blockcast(
    cframe: CFrameLike,
    size: Vector3Like,
    direction: Vector3Like,
    color?: Color3Like,
    parent?: Instance
  ): Folder;
  function triangle(
    pointA: Vector3Like,
    pointB: Vector3Like,
    pointC: Vector3Like,
    color?: Color3Like,
    parent?: Instance
  ): Folder;
  function raycast(
    origin: Vector3,
    direction: Vector3,
    color?: Color3,
    parent?: Instance,
    diameter?: number
  ): BasePart;
  function ray(
    ray: Ray,
    color?: Color3Like,
    parent?: Instance,
    diameter?: number
  ): BasePart;
  function updateRay(
    rayPart: BasePart,
    ray: Ray,
    color?: Color3,
    diameter?: number
  ): void;
  function text(
    adornee: Instance | Vector3,
    text: string,
    color?: Color3Like
  ): Instance;
  function sphere(
    position: Vector3Like,
    radius: number,
    color?: Color3,
    parent?: Instance
  ): BasePart;
  function point(
    position: Vector3Like,
    color?: Color3Like,
    parent?: Instance,
    diameter?: number
  ): BasePart;
  function labelledPoint(
    position: Vector3Like,
    label: string,
    color?: Color3Like,
    parent?: Instance
  ): BasePart;
  function cframe(cframe: CFrameLike): Model;
  function part(
    template: BasePart,
    cframe?: CFrameLike,
    color?: Color3Like,
    transparency?: number
  ): BasePart;
  function box(
    cframe: CFrameLike,
    size: Vector3Like,
    color?: Color3Like
  ): BasePart;
  function region3(region3: Region3, color?: Color3Like): BasePart;
  function terrainCell(position: Vector3Like, color?: Color3Like): BasePart;
  function screenPointLine(
    a: Vector2,
    b: Vector2,
    parent: Instance | undefined,
    color: Color3Like
  ): Frame;
  function screenPoint(
    position: Vector2,
    parent: Instance,
    color?: Color3Like,
    diameter?: number
  ): Frame;
  function vector(
    position: Vector3Like,
    direction: Vector3Like,
    color?: Color3,
    parent?: Instance,
    meshDiameter?: number
  ): BasePart;
  function ring(
    position: Vector3Like,
    normal: Vector3Like,
    radius?: number,
    color?: Color3Like,
    parent?: Instance
  ): Folder;
  function getDefaultParent(): Instance | undefined;
}
