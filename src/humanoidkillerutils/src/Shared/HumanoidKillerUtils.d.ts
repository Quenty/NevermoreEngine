export namespace HumanoidKillerUtils {
  function untagKiller(humanoid: Humanoid): void;
  function tagKiller(humanoid: Humanoid, attacker: Player): ObjectValue;
  function getKillerHumanoidOfHumanoid(
    humanoid: Humanoid
  ): Humanoid | undefined;
  function getPlayerKillerOfHumanoid(humanoid: Humanoid): Player | undefined;
}
