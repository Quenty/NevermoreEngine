export namespace CharacterUtils {
  function getPlayerHumanoid(player: Player): Humanoid | undefined;
  function getAlivePlayerHumanoid(player: Player): Humanoid | undefined;
  function getAlivePlayerRootPart(player: Player): BasePart | undefined;
  function getPlayerRootPart(player: Player): BasePart | undefined;
  function unequipTools(player: Player): void;
  function getPlayerFromCharacter(descendant: Instance): Player | undefined;
}
