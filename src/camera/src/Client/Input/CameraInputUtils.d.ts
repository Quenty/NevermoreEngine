export namespace CameraInputUtils {
  function getPanBy(panDelta: Vector2, sensitivity: Vector2): Vector2;
  function convertToPanDelta(vector3: Vector3): Vector2;
  function getInversionVector(userGameSettings: UserGameSettings): Vector2;
  function invertSensitivity(sensitivity: Vector2): Vector2;
  function isPortraitMode(aspectRatio: number): boolean;
  function getCappedAspectRatio(viweportSize: Vector2): number;
}
