export namespace SunPositionUtils {
  function getGeographicalLatitudeFromDirection(direction: Vector3): number;
  const getGeographicalLatitudeFromMoonDirection: typeof getGeographicalLatitudeFromDirection;
  function getClockTimeFromDirection(direction: Vector3): number;
  function getClockTimeFromMoonDirection(direction: Vector3): number;
  function getDirection(
    azimuthRad: number,
    altitudeRad: number,
    north: Vector3
  ): Vector3;
  function getSunPosition(
    clockTime: number,
    geoLatitude: number
  ): LuaTuple<[sunPosition: Vector3, moonPosition: Vector3]>;
}
