export namespace UICornerUtils {
  function fromScale(scale: number, parent?: Instance): UICorner;
  function fromOffset(offset: number, parent?: Instance): UICorner;
  function clampPositionToFrame(
    framePosition: Vector2,
    frameSize: Vector2,
    radius: number,
    point: Vector2
  ): LuaTuple<[position?: Vector2, normal?: Vector2]>;
}
