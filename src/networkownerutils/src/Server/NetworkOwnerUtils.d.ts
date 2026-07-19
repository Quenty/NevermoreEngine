export namespace NetworkOwnerUtils {
  function trySetNetworkOwner(part: BasePart, player?: Player): boolean;
  function getNetworkOwnerPlayer(part: BasePart): Player | undefined;
  function isNetworkOwner(part: BasePart, player: Player): boolean;
  function isServerNetworkOwner(part: BasePart): boolean;
  function tryToGetNetworkOwner(
    part: BasePart
  ): LuaTuple<[success: boolean, player: Player | undefined]>;
}
