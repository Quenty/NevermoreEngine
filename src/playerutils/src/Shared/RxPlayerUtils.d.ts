export namespace PlayerUtils {
  function formatName(player: Player): string;
  function formatDisplayName(name: string, displayName: string): string;
  function formatDisplayNameFromUserInfo(userInfo: {
    Username: string;
    DisplayName: string;
    HasVerifiedBadge: boolean;
  }): string;
  function addVerifiedBadgeToName(name: string): string;
  function getDefaultNameColor(displayName: string): Color3;
  function promiseLoadCharacter(player: Player): Promise<Model>;
  function promiseLoadCharacterWithHumanoidDescription(
    player: Player,
    humanoidDescription: HumanoidDescription
  ): Promise<Model>;
}
