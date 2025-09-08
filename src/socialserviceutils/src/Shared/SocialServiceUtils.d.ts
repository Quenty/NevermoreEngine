import { Promise } from '@quenty/promise';

export namespace SocialServiceUtils {
  function promiseCanSendGameInvite(player: Player): Promise<boolean>;
  function promisePromptGameInvite(
    player: Player,
    options?: ExperienceInviteOptions
  ): Promise;
}
