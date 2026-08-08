import { Promise } from '@quenty/promise';

export namespace TeleportServiceUtils {
  function promiseReserveServer(placeId: number): Promise<string>;
  function promiseTeleport(
    placeId: number,
    players: Player[],
    teleportOptions?: TeleportOptions
  ): Promise<string>;
}
