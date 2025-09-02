interface BadgeInfo {
  Name: string;
  Description: string;
  IconImageId: number;
  IsEnabled: boolean;
}

export namespace BadgeUtils {
  function promiseAwardBadge(player: Player, badgeId: number): Promise<void>;
  function promiseBadgeInfo(badgeId: number): Promise<BadgeInfo>;
  function promiseUserHasBadge(
    userId: number,
    badgeId: number
  ): Promise<boolean>;
}
