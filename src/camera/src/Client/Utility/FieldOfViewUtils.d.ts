export namespace FieldOfViewUtils {
  function fovToHeight(fov: number): number;
  function heightToFov(height: number): number;
  function safeLog(height: number, linearAt: number): number;
  function safeExp(logHeight: number, linearAt: number): number;
  function lerpInHeightSpace(
    fov0: number,
    fov1: number,
    percent: number
  ): number;
}
