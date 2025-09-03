export namespace TerrainUtils {
  function getTerrainRegion3(
    position: Vector3,
    size: Vector3,
    resolution: number
  ): Region3;
  function getTerrainRegion3int16FromRegion3(
    region3: Region3,
    resolution: number
  ): Region3int16;
  function getCorner(region3: Region3): Vector3;
  function getCornerint16(region3: Region3, resolution: number): Vector3int16;
}
